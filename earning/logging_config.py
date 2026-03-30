import logging
import os

# Allow control via LOG_LEVEL (preferred) or VERBOSE (legacy boolean-like).
log_level = os.getenv('LOG_LEVEL')
verbose = os.getenv('VERBOSE')

if log_level:
    level = getattr(logging, log_level.upper(), logging.INFO)
else:
    if verbose and verbose.lower() in ('0', 'false', 'no'):
        level = logging.WARNING
    else:
        level = logging.INFO

logging.basicConfig(
    level=level,
    format='%(asctime)s %(levelname)s %(name)s: %(message)s',
)

logger = logging.getLogger('applications inserts logger')
