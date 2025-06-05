# utils/db_cleaner.py
import sqlite3

def delete_rows(db_path: str, rowids: list[int]) -> None:
    """
    Delete all rows in tc900log whose rowid is in the provided list.
    Operates in a single transaction using WAL mode.
    """
    if not rowids:
        return

    try:
        conn = sqlite3.connect(db_path, timeout=30)
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("BEGIN;")
        placeholders = ",".join("?" for _ in rowids)
        sql = f"DELETE FROM tc900log WHERE rowid IN ({placeholders})"
        conn.execute(sql, rowids)
        conn.execute("COMMIT;")
    except sqlite3.Error:
        conn.execute("ROLLBACK;")
        raise
    finally:
        conn.close()
