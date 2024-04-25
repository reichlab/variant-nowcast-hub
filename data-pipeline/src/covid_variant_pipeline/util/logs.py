import json
import logging
import traceback
from pathlib import Path


class JsonFormatter(logging.Formatter):
    """JSON log formatter."""

    def format(self, record: logging.LogRecord) -> str:
        log_dict = record.__dict__.copy()

        log_dict["args"] = [str(arg) for arg in record.args or []]
        log_dict["msg"] = record.getMessage()

        # if there's exception info, include it
        if record.exc_info:
            exception = traceback.format_exception(*record.exc_info)
            log_dict["exc_info"] = exception

        return json.dumps(log_dict)


class LoggerSetup:
    def __init__(self, logger_name: str, config_file: str = "pyproject.toml"):
        self.logger_name = logger_name
        self.config_file = config_file
        self.logger = logging.getLogger(self.logger_name)

    def create_log_file(self, log_file: str) -> Path:
        """If logging to a file, create the file if it doesn't exist."""
        log_file_path = Path(log_file)
        log_file_path.parent.mkdir(parents=True, exist_ok=True)
        log_file_path.touch(exist_ok=True)
        return log_file_path

    def init_logger(self):
        """Initialize the application's root logger."""
        # Add default handler for logging to stdout
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            "%(asctime)s -  %(levelname)s - %(name)s - %(message)s", datefmt="%m/%d/%Y %I:%M:%S %p"
        )
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)

        self.logger.setLevel(logging.INFO)
