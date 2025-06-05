# utils/db_cleaner.py

import sqlite3

def delete_rows(db_path: str, table_name: str, rowids: list[int]) -> None:
    """
    Delete rows from the specified table where rowid is in the provided list.
    Executes a single DELETE ... WHERE rowid IN (…) in one transaction.
    """
    if not rowids:
        return

    conn = sqlite3.connect(db_path, timeout=30)
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("BEGIN;")
        placeholders = ",".join("?" for _ in rowids)
        sql = f"DELETE FROM {table_name} WHERE rowid IN ({placeholders})"
        conn.execute(sql, rowids)
        conn.execute("COMMIT;")
    except sqlite3.Error:
        conn.execute("ROLLBACK;")
        raise
    finally:
        conn.close()


def delete_all_rows(db_path: str, table_name: str) -> None:
    """
    Delete all rows from the specified table.
    If the table is already empty, do nothing.
    """
    conn = sqlite3.connect(db_path, timeout=30)
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        cursor = conn.cursor()
        cursor.execute(f"SELECT EXISTS(SELECT 1 FROM {table_name} LIMIT 1);")
        has_rows = cursor.fetchone()[0] == 1
        if has_rows:
            conn.execute("BEGIN;")
            conn.execute(f"DELETE FROM {table_name};")
            conn.execute("COMMIT;")
    except sqlite3.Error:
        conn.execute("ROLLBACK;")
        raise
    finally:
        conn.close()
