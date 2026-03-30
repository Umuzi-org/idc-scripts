import os

import psycopg2
from dotenv import load_dotenv
from logging_config import logger

load_dotenv()


def connect_to_database():
    """Create and return a psycopg2 connection using environment variables.

    Returns None on failure.
    """

    # Get db details
    dbname = os.environ.get('dbname')
    user = os.environ.get('user')
    password = os.environ.get('password')
    host = os.environ.get('host')
    port = os.environ.get('port')

    conn = None

    try:
        # Connect to database
        conn = psycopg2.connect(dbname=dbname, user=user, password=password,
                                host=host, port=port)
        logger.info("Connection to specified %s is successful!", dbname)

    except psycopg2.Error as e:
        logger.error("Error during connection trial: %s", e)
        conn = None

    return conn
