# utils/db_cleaner.py

import sqlite3
from typing import List, Tuple

def delete_rows(db_path: str, table_name: str, rowids: List[int]) -> None:
    """
    Delete rows from the specified table where rowid is in the provided list.
    Executes a single DELETE ... WHERE rowid IN (…) in one transaction,
    then compacts the database file to reclaim space (VACUUM).
    """
    if not rowids:
        return

    placeholders = ",".join("?" for _ in rowids)
    delete_sql = f"DELETE FROM {table_name} WHERE rowid IN ({placeholders})"
    _execute_delete(db_path, delete_sql, tuple(rowids))


def delete_all_rows(db_path: str, table_name: str) -> None:
    """
    Delete all rows from the specified table. If the table is already empty,
    do nothing. After deletion, compacts the database file (VACUUM).
    """
    conn = sqlite3.connect(db_path, timeout=30)
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        cursor = conn.cursor()
        cursor.execute(f"SELECT EXISTS(SELECT 1 FROM {table_name} LIMIT 1);")
        has_rows = bool(cursor.fetchone()[0])
    finally:
        conn.close()

    if not has_rows:
        return

    delete_sql = f"DELETE FROM {table_name};"
    _execute_delete(db_path, delete_sql)

# Helpers
def _execute_delete(db_path: str, delete_sql: str, params: Tuple = ()) -> None:
    """
    Helper to execute a DELETE statement inside a transaction and then VACUUM the database.
    """
    conn = sqlite3.connect(db_path, timeout=30)
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("BEGIN;")
        conn.execute(delete_sql, params)
        conn.execute("COMMIT;")
    except sqlite3.Error:
        conn.execute("ROLLBACK;")
        raise
    finally:
        conn.close()

    conn_vac = sqlite3.connect(db_path, timeout=30)
    try:
        conn_vac.execute("VACUUM;")
    finally:
        conn_vac.close()
