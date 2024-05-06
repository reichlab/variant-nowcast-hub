# from util.logs import get_logger
import requests
import structlog

logger = structlog.get_logger()


def get_reference_data(session: requests.Session, as_of_date: str) -> dict:
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

    reference_data = response.json()

    logger.info(
        "Reference data retrieved",
        tree_updated=reference_data["meta"].get("updated"),
    )

    reference = {
        "tree": reference_data["tree"],
        "meta": reference_data["meta"],
    }

    try:
        reference["root_sequence"] = reference_data["root_sequence"]
    except KeyError as e:
        # Older versions of the dataset don't include a root_sequence. Depending on how
        # far back in time we're going, we may need to handle this scenario. For now,
        # raise an exception, since we won't have root sequence info to pass to the clade assignment.
        logger.exception("No root sequence found in reference data.")
        raise e

    return reference
