# from util.logs import get_logger
import requests
import structlog

logger = structlog.get_logger()


def get_reference_tree(session: requests.Session, as_of_date: str) -> dict:
    """Return a reference tree as of a given date in YYYY-MM-DD format."""

    base_url = "https://nextstrain.org/nextclade/sars-cov-2"
    response = session.get(f"{base_url}@{as_of_date}")

    if not response.ok:
        logger.error(
            {
                "message": f"Failed to get reference tree as of {as_of_date}.",
                "status_code": response.status_code,
                "request": response.request.url,
                "response": response.text,
            }
        )

    tree_data = response.json()

    logger.info(
        "Reference tree retrieved",
        tree_updated=tree_data["meta"].get("updated"),
    )

    return tree_data
