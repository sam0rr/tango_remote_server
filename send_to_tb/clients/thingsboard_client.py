#!/usr/bin/env python3
"""
thingsboard_client.py — ThingsBoard-specific HTTP client subclass.
"""
import logging
from .http_client import HttpClient

log = logging.getLogger("thingsboard_client")


class ThingsBoardClient(HttpClient):
    """
    HttpClient configured for ThingsBoard using constructor injection.
    """

    def __init__(self, device_token: str, max_retry: int, initial_delay: float,
                 timeout: int, min_batch_size_to_split: int):
        """
        Initialize the ThingsBoard client with explicitly provided settings.
        """
        post_url = f"https://thingsboard.cloud/api/v1/{device_token}/telemetry"
        super().__init__(
            post_url=post_url,
            max_retry=max_retry,
            initial_delay=initial_delay,
            timeout=timeout,
            min_batch_size_to_split=min_batch_size_to_split
        )
        self._log_config(post_url, max_retry, initial_delay, timeout, min_batch_size_to_split)

    def _log_config(self, url, retry, delay, timeout, split):
        """
        Log ThingsBoard client configuration.
        """
        log.info("Initialized ThingsBoardClient with:")
        log.info("  post_url = %s", url)
        log.info("  max_retry = %s", retry)
        log.info("  initial_delay = %s", delay)
        log.info("  timeout = %s", timeout)