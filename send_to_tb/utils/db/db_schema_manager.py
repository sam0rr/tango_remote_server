# utils/db/db_schema_manager.py

import logging
from sqlite3 import Error
from utils.db.db_connect import get_sqlite_connection

logger = logging.getLogger(__name__)

def ensure_schema(db_path: str, table: str, time_column: str, target_version: int, timeout: float) -> None:
    """
    Ensure that the given table has a time column & trigger, and that
    PRAGMA user_version equals target_version.
    """
    try:
        with get_sqlite_connection(db_path, timeout=timeout) as conn:
            cur = conn.cursor()

            current_version = _get_user_version(cur)
            logger.debug("Current schema version for '%s': %d", table, current_version)

            if current_version < target_version:
                logger.info("Migrating table '%s' from v%d → v%d", table, current_version, target_version)
                _add_time_column(cur, table, time_column)
                _create_time_trigger(cur, table, time_column)
                _set_user_version(cur, target_version)
                conn.commit()
            else:
                logger.debug("No migration needed for '%s' (already at v%d)", table, current_version)

    except Error as e:
        logger.exception("Schema migration failed for '%s': %s", table, e)
        raise


def _get_user_version(cursor) -> int:
    """Read PRAGMA user_version from the database."""
    cursor.execute("PRAGMA user_version;")
    return cursor.fetchone()[0]


def _set_user_version(cursor, version: int) -> None:
    """Set PRAGMA user_version to the given integer."""
    cursor.execute(f"PRAGMA user_version = {version};")
    logger.debug("Set PRAGMA user_version to %d", version)


def _add_time_column(cursor, table: str, column: str) -> None:
    """
    Ensure the time-column exists (INTEGER, default 0) on the given table.
    This will backfill any missing rows to 0, so we can safely apply the trigger next.
    """
    sql = f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} INTEGER DEFAULT 0;"
    cursor.execute(sql)
    logger.info("Ensured column '%s' exists on '%s'", column, table)


def _create_time_trigger(cursor, table: str, column: str) -> None:
    """
    Create an AFTER INSERT trigger that stamps new rows'
    `{column}` with the current time in milliseconds.
    """
    trigger_name = f"set_{column}_on_{table}"
    sql = f"""
      CREATE TRIGGER IF NOT EXISTS {trigger_name}
      AFTER INSERT ON {table}
      BEGIN
        UPDATE {table}
           SET {column} = CAST(strftime('%s','now') AS INTEGER) * 1000
         WHERE rowid = NEW.rowid;
      END;
    """
    cursor.execute(sql)
    logger.info("Ensured trigger '%s' exists on '%s'", trigger_name, table)

