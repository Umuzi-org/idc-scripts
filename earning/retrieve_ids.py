# Needed libraries
import psycopg2
from typing import Dict, List, Set, Any, Tuple
from logging_config import logger


def build_where_clause(filters: Dict[str, List[Any]]) -> Tuple[str, List[Any]]:
    """
    Builds a WHERE clause for multiple fields, each using IN.
    Returns the clause and the flattened list of values for psycopg2.
    """
    clauses = []
    params = []
    for field, values in filters.items():
        placeholders = ','.join(['%s'] * len(values))
        clauses.append(f"{field} IN ({placeholders})")
        params.extend(values)
    where_clause = " AND ".join(clauses)
    return where_clause, params

def get_ids_by_fields(
    filters: Dict[str, List[Any]],
    conn,
    table: str,
    fields: Set[str]
) -> List[dict]:
    """
    Retrieves rows from the specified table based on arbitrary field filters.

    Parameters:
        filters: Dict of {field: [values]} to filter by.
        conn: Active database connection.
        table: Table to query.
        fields: Set of fields to retrieve.

    Returns:
        List of dicts mapping field names to values.
    """
    if not filters or not table or not fields:
        return []

    if conn:
        try:
            cur = conn.cursor()
            fields_str = ", ".join(fields)
            where_clause, params = build_where_clause(filters)
            query = f"""
                SELECT {fields_str}
                FROM {table}
                WHERE {where_clause};
            """
            cur.execute(query, params)
            rows = cur.fetchall()
            result = [dict(zip(fields, row)) for row in rows]
            # cur.close()
            # conn.close()
            return result
        except psycopg2.Error as e:
            # Log the error and return empty list. Do NOT close the connection here;
            # connection lifecycle and transaction boundaries should be managed by
            # the caller so they can decide whether to rollback/close or retry.
            logger.error("Error retrieving data from %s: %s", table, e)
            return []
    else:
        logger.warning("No active database connection provided to get_ids_by_fields")
        return []

