#!/usr/bin/env python3
"""
http_client.py — Generic HTTP client with back-off/retry logic, cleanly modularized.
"""
import time
import random
import logging
import requests

log = logging.getLogger("http_client")


class HttpClient:
    """
    Generic HTTP client:
      - post_json_with_retry(): send JSON with retries & back-off.
      - send_resilient(): send batches, splitting on failure.
    """

    def __init__(self, post_url: str, max_retry: int = 5, initial_delay: float = 0.2,
                 timeout: int = 10, min_batch_size_to_split: int = 2):
        self.post_url = post_url
        self.max_retry = max_retry
        self.initial_delay = initial_delay
        self.timeout = timeout
        self.min_batch_size_to_split = min_batch_size_to_split

    def _attempt_post(self, payload: list[dict]) -> requests.Response | None:
        """Attempt a single POST request."""
        try:
            return requests.post(
                self.post_url,
                headers={"Content-Type": "application/json"},
                json=payload,
                timeout=self.timeout
            )
        except Exception as exc:
            log.warning("Network exception: %s", exc)
            return None

    def _handle_retry_delay(
        self, response: requests.Response, delay: float, attempt: int
    ) -> float:
        """Apply back-off based on Retry-After header or double delay."""
        retry_after = response.headers.get("Retry-After")
        try:
            pause = float(retry_after) if retry_after else delay
        except ValueError:
            pause = delay

        log.warning(
            "HTTP %d → sleeping %.2fs (attempt %d/%d)",
            response.status_code, pause, attempt, self.max_retry
        )
        time.sleep(pause)
        
        new_delay = delay * 2
        new_delay += random.uniform(0, new_delay / 2)
        return new_delay

    def post_json_with_retry(self, payload: list[dict]) -> bool:
        """
        Send a single JSON payload (list of dicts) with retry/back-off.
        Returns True on success, False on failure.
        """
        delay = self.initial_delay

        for attempt in range(1, self.max_retry + 1):
            response = self._attempt_post(payload)
            if response is None:
                log.warning("Request failed → retrying in %.2fs", delay)
                time.sleep(delay)
                delay *= 2
                continue

            code = response.status_code
            if 200 <= code < 300:
                return True
            if self._should_retry(code):
                delay = self._handle_retry_delay(response, delay, attempt)
                continue

            return self._log_and_drop(code, response)

        log.error("Exhausted retries for payload. Dropping.")
        return False

    def send_resilient(self, batch: list[dict]) -> int:
        """
        Attempt to send the full batch.
        If it fails, split and retry.
        If it's a single item and fails, drop it.
        """
        if not batch:
            return 0

        if self.post_json_with_retry(batch):
            return len(batch)

        if len(batch) == 1:
            return self._handle_failed_single(batch[0])

        if len(batch) < self.min_batch_size_to_split:
            log.error("Cannot split batch further. Dropping.")
            return 0

        left, right = self._split_batch(batch)
        return self.send_resilient(left) + self.send_resilient(right)

    @staticmethod
    def _should_retry(status_code: int) -> bool:
        """Return True if status_code is retriable (e.g. 429, 500, 502-504)."""
        return status_code in (429, 500, 502, 503, 504)

    @staticmethod
    def _log_and_drop(status_code: int, response: requests.Response) -> bool:
        """Log specific error and stop retrying."""
        if status_code == 401:
            log.error("Unauthorized (401): check DEVICE_TOKEN or permissions.")
        else:
            log.error("HTTP %d error: %s", status_code, response.text.strip())
        return False

    @staticmethod
    def _split_batch(batch: list[dict]) -> tuple[list[dict], list[dict]]:
        """Split batch in two halves."""
        mid = len(batch) // 2
        return batch[:mid], batch[mid:]

    @staticmethod
    def _handle_failed_single(payload: dict) -> int:
        """Log dropped payload with RowId and return 0."""
        row_id = payload.get("values", {}).get("RowId", "?")
        log.error("Dropping RowId=%s", row_id)
        return 0
