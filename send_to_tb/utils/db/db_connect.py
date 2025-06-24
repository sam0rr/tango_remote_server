# utils/db/db_connect.py

import sqlite3

def get_sqlite_connection(db_path: str, timeout: float) -> sqlite3.Connection:
    """
    Opens a SQLite connection with WAL mode, NORMAL sync, and Row factory enabled.
    Returns the configured sqlite3.Connection object.
    """
    conn = sqlite3.connect(db_path, timeout=timeout)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn
