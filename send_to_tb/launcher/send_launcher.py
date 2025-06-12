#!/usr/bin/env python3
"""
send_launcher.py — Batch launcher with post-send batch deletion.
Orchestrates:
  1) fetch_and_prepare() from DataFetcher (returns list of payloads with "rowid")
  2) chunk payloads by max_batch_size
  3) send each batch via HttpClient.send_resilient()
  4) for each batch, if fully sent, collect ALL rowids and delete them in bulk
  5) enforce batch_window_sec delay between batches
  6) at the end, clear all rows from the alarm table
"""

import time
import logging
from utils.db.db_cleaner import delete_rows, delete_all_rows

log = logging.getLogger("send_launcher")


class SendToLauncher:
    """
    Launches the telemetry pipeline by combining a DataFetcher and HttpClient.
    Payloads are sent in batches of max_batch_size; each batch fully sent
    has all its rowids collected and deleted in one SQL transaction.
    After all batches are processed, the alarms table is cleared.
    """

    def __init__(self, fetcher, client, max_batch_size: int, batch_window_sec: float = 1.0):
        """
        :param fetcher:         Instance of DataFetcher (fetcher.db_path must exist)
        :param client:          Instance of HttpClient (ThingsBoardClient)
        :param max_batch_size:  Max number of payloads per batch
        :param batch_window_sec: Delay in seconds between batch sends
        """
        self.fetcher = fetcher
        self.client = client
        self.max_batch_size = max_batch_size
        self.batch_window_sec = batch_window_sec

    def _fetch_payloads(self) -> list[dict]:
        """
        Retrieve fresh telemetry payloads from the fetcher.
        Each payload is a dict containing keys "rowid", "ts", and "values".
        """
        payloads, *_ = self.fetcher.fetch_and_prepare()
        return payloads

    def _send_in_chunks(self, payloads: list[dict]) -> None:
        """
        Loop through payloads in batches of max_batch_size,
        delegate each batch to _process_batch(),
        and enforce delay between batches.
        """
        total = len(payloads)
        log.info(f"Processing {total} payload(s) in batches of {self.max_batch_size}.")
        if total == 0:
            return

        for batch_no, start in enumerate(range(0, total, self.max_batch_size), start=1):
            batch = payloads[start: start + self.max_batch_size]
            self._process_batch(batch, batch_no)
            time.sleep(self.batch_window_sec)

        log.info("All batches processed.")

    def _process_batch(self, batch: list[dict], batch_no: int) -> None:
        """
        Send one batch via client.send_resilient(),
        delete its rowids if fully sent, and log the result.
        """
        sent = self.client.send_resilient(batch)

        if sent == len(batch):
            self._delete_batch_rowids(batch)

        log.info(f"Batch {batch_no}: sent {sent}/{len(batch)}")

    def _delete_batch_rowids(self, batch: list[dict]) -> None:
        """
        Collect all rowids from a batch and delete them in one SQL transaction.
        """
        rowids = [entry["rowid"] for entry in batch if entry.get("rowid") is not None]
        if not rowids:
            return

        delete_rows(
            db_path=self.fetcher.db_path,
            table_name=self.fetcher.tables["telemetry"],
            rowids=rowids,
            timeout=self.fetcher.timeout
        )

    def start(self):
        """
        Entry point:
          1) Fetch all payloads (list of dicts with "rowid", "ts", "values").
          2) Chunk them by max_batch_size and call _send_in_chunks().
          3) After all telemetry rows are sent & deleted, clear the alarm table.
        """
        payloads = self._fetch_payloads()
        self._send_in_chunks(payloads)

        delete_all_rows(
            db_path=self.fetcher.db_path,
            table_name=self.fetcher.tables["alarm"],
            timeout=self.fetcher.timeout
        )

        self.client.close()
