#!/usr/bin/env python3
"""
send_launcher.py — Fine-grained launcher with post-send batch deletion.
Orchestrates:
  1) fetch_and_prepare() from DataFetcher (returns list of payloads with "rowid")
  2) chunk payloads by max_per_sec
  3) send each one via HttpClient.send_resilient()
  4) for each mini-batch, collect ALL rowids and delete them in bulk
  5) enforce 1s delay between batches
  6) at the end, clear all rows from the alarm table
"""

import time
import logging
from utils.db.db_cleaner import delete_rows, delete_all_rows

log = logging.getLogger("send_launcher")


class SendToLauncher:
    """
    Launches the telemetry pipeline by combining a DataFetcher and HttpClient.
    Payloads are sent in small batches; each successfully sent payload's rowid
    is collected, then all collected rowids are deleted in one SQL transaction.
    After that, the alarms table is cleared if it contains any rows.
    """

    def __init__(self, fetcher, client, max_per_sec: int, batch_window_sec: float = 1.0):
        """
        :param fetcher:     Instance of DataFetcher (fetcher.db_path must exist)
        :param client:      Instance of HttpClient (ThingsBoardClient)
        :param max_per_sec: Max number of messages to send per second
        :param batch_window_sec: Time window in seconds between batch sends
        """
        self.fetcher = fetcher
        self.client = client
        self.max_per_sec = max_per_sec
        self.batch_window_sec = batch_window_sec

    def _fetch_payloads(self) -> list[dict]:
        """
        Retrieve fresh telemetry payloads from the fetcher.
        Each payload is a dict containing keys "rowid", "ts", and "values".
        """
        result = self.fetcher.fetch_and_prepare()
        return result if isinstance(result, list) else result[0]

    def _send_in_chunks(self, payloads: list[dict]) -> None:
        """
        Loop through payloads in chunks of max_per_sec, call _send_fine_grained_batch,
        then apply a delay before processing the next chunk.
        """
        total = len(payloads)
        log.info("Processing %d payload(s).", total)
        if total == 0:
            return

        sent_count = 0
        batch: list[dict] = []
        window_start = time.monotonic()

        for entry in payloads:
            batch.append(entry)

            if len(batch) >= self.max_per_sec:
                sent_count += self._send_fine_grained_batch(batch)
                window_start = self._enforce_rate_limit(window_start)
                batch.clear()

        if batch:
            sent_count += self._send_fine_grained_batch(batch)

        log.info("Done. Sent %d/%d payload(s).", sent_count, total)

    def _send_fine_grained_batch(self, batch: list[dict]) -> int:
        """
        Send each message individually, collect all successful rowids,
        then delete them in one single transaction at the end.
        Returns the number of successfully sent payloads.
        """
        sent_total = 0
        rowids_to_delete: list[int] = []

        for entry in batch:
            payload = {
                "ts": entry["ts"],
                "values": entry["values"]
            }

            try:
                sent = self.client.send_resilient([payload])
                if sent:
                    rowid = entry.get("rowid")
                    if rowid is not None:
                        rowids_to_delete.append(rowid)
                    sent_total += 1
            except Exception as e:
                log.warning("Failed to send single payload: %s", e)

        if rowids_to_delete:
            delete_rows(
                db_path=self.fetcher.db_path,
                table_name=self.fetcher.tables["telemetry"],
                rowids=rowids_to_delete,
                timeout=self.fetcher.timeout
            )

        return sent_total

    def _enforce_rate_limit(self, window_start: float) -> float:
        """
        Sleep the remaining time to enforce a minimum batch window.
        """
        elapsed = time.monotonic() - window_start
        if elapsed < self.batch_window_sec:
            time.sleep(self.batch_window_sec - elapsed)
        return time.monotonic()

    def start(self):
        """
        Entry point:
          1) Fetch all payloads (list of dicts with "rowid", "ts", "values").
          2) Chunk them by max_per_sec and call _send_fine_grained_batch().
          3) After all telemetry rows are sent & deleted, clear the alarm table.
        """
        payloads = self._fetch_payloads()
        self._send_in_chunks(payloads)

        delete_all_rows(
            db_path=self.fetcher.db_path,
            table_name=self.fetcher.tables["alarm"],
            timeout=self.fetcher.timeout
        )
