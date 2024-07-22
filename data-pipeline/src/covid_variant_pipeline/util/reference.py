"""Functions for retrieving and parsing SARS-CoV-2 phylogenic tree data."""

import requests
import structlog
from covid_variant_pipeline.util.session import check_response, get_session

logger = structlog.get_logger()


def get_reference_data(base_url: str, as_of_date: str) -> dict:
    """Return a reference tree as of a given date in YYYY-MM-DD format."""
    headers = {
        "Accept": "application/vnd.nextstrain.dataset.main+json",
    }
    session = get_session()
    session.headers.update(headers)

    response = requests.get(f"{base_url}@{as_of_date}", headers=headers)
    check_response(response)
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
        # this code adds a fasta-compliant header to the root sequence returned by the API
        fasta_root_header = (
            ">NC_045512.2 Severe acute respiratory syndrome" " coronavirus 2 isolate Wuhan-Hu-1, complete genome"
        )
        root_sequence = reference_data["root_sequence"]["nuc"]
        reference["root_sequence"] = f"{fasta_root_header}\n{root_sequence}"
    except KeyError:
        # Older versions of the dataset don't include a root_sequence.
        logger.error("Aborting pipeline: no root sequence found in reference data.", as_of_date=as_of_date)
        raise SystemExit(f"\nAborting pipeline: no root sequence found for date {as_of_date}")

    return reference
