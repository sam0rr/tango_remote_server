#!/usr/bin/env python3
"""
send_launcher.py — Fine-grained launcher with rowid update per message.
Orchestrates:
  1) fetch_and_prepare() from DataFetcher
  2) chunk payloads by max_per_sec
  3) send each one via HttpClient.send_resilient()
  4) update state_file (rowid) after *each message*
  5) enforce 1s delay between batches
"""
import time
import logging

log = logging.getLogger("send_launcher")


class SendToLauncher:
    """
    Launches the telemetry pipeline by combining a DataFetcher and HttpClient.
    Payloads are sent in small batches with per-message state persistence
    to maximize reliability in case of crash.
    """

    def __init__(self, fetcher, client, max_per_sec: int):
        """
        :param fetcher:     Instance of DataFetcher
        :param client:      Instance of HttpClient
        :param max_per_sec: Max number of messages to send per second
        """
        self.fetcher = fetcher
        self.client = client
        self.max_per_sec = max_per_sec

    def _fetch_payloads(self) -> list[dict]:
        """
        Retrieve fresh telemetry payloads from the fetcher.
        """
        payloads, _ = self.fetcher.fetch_and_prepare()
        return payloads

    def _send_in_chunks(self, payloads: list[dict]) -> None:
        """
        Loop through payloads, batch them by max_per_sec, send each message
        individually, and write the rowid after every successful send.
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
        Send each message individually and write rowid after each success.
        Returns the number of successfully sent payloads.
        """
        sent_total = 0

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
                        self.fetcher.write_last_id(rowid)
                        log.debug("RowID %d sent and written to state file", rowid)
                    sent_total += 1
            except Exception as e:
                log.warning("Failed to send single payload: %s", e)

        return sent_total

    def _enforce_rate_limit(self, window_start: float) -> float:
        """
        Sleep the remaining time to enforce a minimum 1s window per batch.
        """
        elapsed = time.monotonic() - window_start
        if elapsed < 1.0:
            time.sleep(1.0 - elapsed)
        return time.monotonic()

    def start(self):
        """
        Entry point — fetch, chunk, send, persist rowid after each message.
        """
        payloads = self._fetch_payloads()
        self._send_in_chunks(payloads)
