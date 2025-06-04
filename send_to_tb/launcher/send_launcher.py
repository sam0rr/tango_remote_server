#!/usr/bin/env python3
"""
send_launcher.py — Orchestrator that ties a DataFetcher to an HttpClient.
Splits big methods into several helpers (<30 lines each).
"""
import time
import logging

log = logging.getLogger("send_launcher")


class SendToLauncher:
    """
    Orchestrate:
      1) fetch_and_prepare() from DataFetcher
      2) chunk payloads by max_per_sec
      3) send each chunk with HttpClient.send_resilient()
      4) update state_file via fetcher.write_last_id()
      5) enforce 1s delay between chunks
    """

    def __init__(self, fetcher, client, max_per_sec: int):
        """
        :param fetcher:     Instance of DataFetcher
        :param client:      Instance of HttpClient
        :param max_per_sec: How many messages to send per second
        """
        self.fetcher = fetcher
        self.client = client
        self.max_per_sec = max_per_sec

    def _fetch_payloads(self) -> tuple[list[dict], int]:
        """
        Call fetcher.fetch_and_prepare() → (payloads, last_seen_id).
        """
        return self.fetcher.fetch_and_prepare()

    def _send_in_chunks(self, payloads: list[dict], last_seen_id: int) -> None:
        """
        Loop through payloads, batch by self.max_per_sec, send each batch,
        update state after each batch, and enforce rate limit.
        """
        total = len(payloads)
        log.info("▶︎ Processing %d payload(s).", total)
        if total == 0:
            log.info("No payloads to send.")
            return

        sent_count = 0
        batch: list[dict] = []
        window_start = time.monotonic()

        for pl in payloads:
            batch.append(pl)
            if len(batch) >= self.max_per_sec:
                sent_count += self._send_single_batch(batch)
                window_start = self._enforce_rate_limit(window_start)
                batch.clear()

        if batch:
            sent_count += self._send_single_batch(batch)
            self.fetcher.write_last_id(last_seen_id)

        log.info("✅ Done. Sent %d/%d payload(s).", sent_count, total)

    def _send_single_batch(self, batch: list[dict]) -> int:
        """
        Send `batch` via client.send_resilient().
        Update last_id to the batch’s last RowId.
        Return number of successfully sent items.
        """
        sent = self.client.send_resilient(batch)
        last_rowid = batch[-1]["values"].get("RowId")
        self.fetcher.write_last_id(last_rowid)
        return sent

    def _enforce_rate_limit(self, window_start: float) -> float:
        """
        If less than 1 second has passed since window_start, sleep the remaining time.
        Return new window_start (now).
        """
        elapsed = time.monotonic() - window_start
        if elapsed < 1.0:
            time.sleep(1.0 - elapsed)
        return time.monotonic()

    def start(self):
        """
        1) _fetch_payloads()
        2) _send_in_chunks(...)
        """
        payloads, last_seen_id = self._fetch_payloads()
        self._send_in_chunks(payloads, last_seen_id)
