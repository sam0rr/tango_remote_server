# utils/db_cleaner.py

import sqlite3
import logging
from typing import List, Tuple

logger = logging.getLogger(__name__)

def delete_rows(db_path: str, table_name: str, rowids: List[int]) -> None:
    """
    Supprime les lignes dont le rowid est dans la liste fournie,
    puis compacte la base (VACUUM).
    """
    if not rowids:
        return

    logger.info("Deleting rowids %s from table '%s'", rowids, table_name)

    placeholders = ",".join("?" for _ in rowids)
    delete_sql = f"DELETE FROM {table_name} WHERE rowid IN ({placeholders})"
    _execute_delete(db_path, delete_sql, tuple(rowids))

def delete_all_rows(db_path: str, table_name: str) -> None:
    """
    Supprime toutes les lignes de la table. Si la table est vide, ne fait rien.
    Puis compacte la base (VACUUM).
    """
    conn = sqlite3.connect(db_path, timeout=30)
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        cursor = conn.cursor()

        cursor.execute(f"SELECT COUNT(*) FROM {table_name};")
        count = cursor.fetchone()[0]

        if count == 0:
            return

        logger.info("Deleting all %d row(s) from table '%s'", count, table_name)
    except sqlite3.Error as e:
        logger.exception("Error checking for existing rows in '%s': %s", table_name, e)
        conn.close()
        raise
    finally:
        conn.close()

    delete_sql = f"DELETE FROM {table_name};"
    _execute_delete(db_path, delete_sql)

def _execute_delete(db_path: str, delete_sql: str, params: Tuple = ()) -> None:
    """
    Exécute la requête DELETE dans une transaction puis fait VACUUM.
    """
    conn = sqlite3.connect(db_path, timeout=30)
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("BEGIN;")
        logger.debug("Executing SQL: %s | Params: %s", delete_sql, params)
        conn.execute(delete_sql, params)
        conn.execute("COMMIT;")
        logger.debug("Transaction committed for SQL: %s", delete_sql)
    except sqlite3.Error as e:
        conn.execute("ROLLBACK;")
        logger.exception("Error executing delete; rolled back transaction: %s", e)
        raise
    finally:
        conn.close()

    try:
        conn_vac = sqlite3.connect(db_path, timeout=30)
        conn_vac.execute("VACUUM;")
        logger.debug("VACUUM completed for database '%s'", db_path)
    except sqlite3.Error as e:
        logger.exception("Error during VACUUM on database '%s': %s", db_path, e)
        raise
    finally:
        conn_vac.close()
