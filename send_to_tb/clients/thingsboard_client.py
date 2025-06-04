#!/usr/bin/env python3
"""
thingsboard_client.py — ThingsBoard-specific HTTP client subclass.
"""
import os
from .http_client import HttpClient


class ThingsBoardClient(HttpClient):
    """
    HttpClient pointed at ThingsBoard, using defaults from environment.
    """

    def __init__(self):
        """
        Pull DEVICE_TOKEN, MAX_RETRY, and INITIAL_DELAY_MS from env.
        """
        device_token = os.getenv("DEVICE_TOKEN", "").strip()
        if not device_token:
            raise RuntimeError("Missing DEVICE_TOKEN in environment")

        post_url = f"https://thingsboard.cloud/api/v1/{device_token}/telemetry"
        max_retry = int(os.getenv("MAX_RETRY", "5"))
        initial_ms = int(os.getenv("INITIAL_DELAY_MS", "200"))
        initial_delay = initial_ms / 1000.0

        super().__init__(
            post_url=post_url,
            max_retry=max_retry,
            initial_delay=initial_delay
        )
