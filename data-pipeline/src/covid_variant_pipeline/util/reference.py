# from util.logs import get_logger
import requests
import structlog

logger = structlog.get_logger()


def get_reference_data(base_url: str, as_of_date: str) -> dict:
    """Return a reference tree as of a given date in YYYY-MM-DD format."""

    headers = {
        "Accept": "application/vnd.nextstrain.dataset.main+json",
        "Accept-Encoding": "gzip, deflate",
    }

    response = requests.get(f"{base_url}@{as_of_date}", headers=headers)

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
        # response schema: https://raw.githubusercontent.com/nextstrain/augur/HEAD/augur/data/schema-export-v2.json
        # root sequence schema: https://raw.githubusercontent.com/nextstrain/augur/HEAD/augur/data/schema-export-root-sequence.json
        # this code adds a fasta-compliant header to the root sequence returned by the API (correct fasta format is required
        # in a subsequent step that uses nextclade to perform clade assignments)
        fasta_root_header = (">NC_045512.2 Severe acute respiratory syndrome"
                            " coronavirus 2 isolate Wuhan-Hu-1, complete genome")
        root_sequence = reference_data["root_sequence"]["nuc"]
        reference["root_sequence"] = f"{fasta_root_header}\n{root_sequence}"
    except KeyError as e:
        # Older versions of the dataset don't include a root_sequence. Depending on how
        # far back in time we're going, we may need to handle this scenario. For now,
        # raise an exception, since we won't have root sequence info to pass to the clade assignment.
        logger.exception("No root sequence found in reference data.")
        raise e

    return reference
