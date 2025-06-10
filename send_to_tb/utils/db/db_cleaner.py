# utils/db_cleaner.py

import logging
from typing import List, Tuple
from sqlite3 import Error
from utils.db.db_connect import get_sqlite_connection

logger = logging.getLogger(__name__)

def delete_rows(db_path: str, table_name: str, rowids: List[int], timeout: float = 30.0) -> None:
    """
    Deletes rows from the table where rowid is in the given list,
    then compacts the database using VACUUM.
    """
    if not rowids:
        return

    logger.info("Deleting rowids %s from table '%s'", rowids, table_name)
    placeholders = ",".join("?" for _ in rowids)
    delete_sql = f"DELETE FROM {table_name} WHERE rowid IN ({placeholders})"
    _execute_delete(db_path, delete_sql, tuple(rowids), timeout=timeout)
    vacuum_database(db_path, timeout)


def delete_all_rows(db_path: str, table_name: str, timeout: float = 30.0) -> None:
    """
    Deletes all rows from the specified table.
    Does nothing if the table is already empty.
    Then compacts the database using VACUUM.
    """
    try:
        with get_sqlite_connection(db_path, timeout=timeout) as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT COUNT(*) FROM {table_name};")
            count = cursor.fetchone()[0]

            if count == 0:
                return

            logger.info("Deleting all %d row(s) from table '%s'", count, table_name)
    except Error as e:
        logger.exception("Error checking for existing rows in '%s': %s", table_name, e)
        raise

    delete_sql = f"DELETE FROM {table_name};"
    _execute_delete(db_path, delete_sql, timeout=timeout)
    vacuum_database(db_path, timeout)


def _execute_delete(db_path: str, delete_sql: str, params: Tuple = (), timeout: float = 30.0) -> None:
    """
    Executes the DELETE statement inside a transaction.
    """
    try:
        with get_sqlite_connection(db_path, timeout=timeout) as conn:
            conn.execute("BEGIN;")
            logger.debug("Executing SQL: %s | Params: %s", delete_sql, params)
            conn.execute(delete_sql, params)
            conn.execute("COMMIT;")
            logger.debug("Transaction committed for SQL: %s", delete_sql)
    except Error as e:
        logger.exception("Error executing delete; rolled back transaction: %s", e)
        try:
            with get_sqlite_connection(db_path, timeout=timeout) as conn_rollback:
                conn_rollback.execute("ROLLBACK;")
        except Exception:
            pass
        raise


def vacuum_database(db_path: str, timeout: float = 30.0) -> None:
    """
    Performs VACUUM to compact the database.
    """
    try:
        with get_sqlite_connection(db_path, timeout=timeout) as conn:
            conn.execute("VACUUM;")
            logger.debug("VACUUM completed for database '%s'", db_path)
    except Error as e:
        logger.exception("Error during VACUUM on database '%s': %s", db_path, e)
        raise
