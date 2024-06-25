"""Common session management code."""

import requests
import structlog
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry  # type: ignore

logger = structlog.get_logger()


def get_session(session: requests.Session = None) -> requests.Session:
    """Return a requests session with retry logic."""

    if session:
        return session

    headers = {
        "Accept-Encoding": "br, deflate, gzip, zstd",
    }

    session = requests.Session()
    # attach a urllib3 retry adapter to the requests session
    # https://urllib3.readthedocs.io/en/latest/reference/urllib3.util.html#urllib3.util.retry.Retry
    retries = Retry(
        total=5,
        allowed_methods=frozenset(["GET", "POST"]),
        backoff_factor=1,
        status_forcelist=[401, 403, 404, 429, 500, 502, 503, 504],
    )
    session.mount("https://", HTTPAdapter(max_retries=retries))
    session.headers.update(headers)

    return session


def check_response(response: requests.Response) -> bool:
    """Check the results of a requests session."""

    if not response.ok:
        # If the session retries the max number of times, the app will throw an error before we get here.
        # So if we're here, it's because the post request failed on an HTTP status not on the above status_forcelist.
        logger.error(
            "Failed to download genome package",
            status_code=response.status_code,
            response_text=response.text,
            request=response.request.url,
            request_body=response.request.body,
        )
        # Exit the pipeline without displaying a traceback
        raise SystemExit(f"Unsuccessful API request: {response.status_code}: {response.reason}")
    else:
        return True
