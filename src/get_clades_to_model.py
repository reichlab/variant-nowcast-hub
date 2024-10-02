"""
Create a list of Sars-CoV-2 clades to model and saves it to the hub's auxiliary-data folder.

This script wraps the virus-clade-utils package, which generates the clade list using the
latest GenBank-based Sars-CoV-2 sequence metadata from Nextstrain.
https://github.com/reichlab/virus-clade-utils

Current parameters for the clade list:
    threshold = .01,
    threshold_weeks = 3 week
    max_clades = 9

The script is scheduled to run every Monday, for use in the modeling round that will open
on the following Wednesday.

To run the script manually:
1. Install uv on your machine: https://docs.astral.sh/uv/getting-started/installation/
2. From the root of this repo: uv run src/get_clades_to_model.py
"""

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "virus_clade_utils@git+https://github.com/reichlab/virus-clade-utils@bsweger/get_nextstrain_ncov_metadata",
# ]
# ///

import json
import logging
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

from virus_clade_utils.cladetime import CladeTime  # type: ignore
from virus_clade_utils import get_clade_list  # type: ignore

# Log to stdout
logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s -  %(levelname)s - %(message)s", datefmt="%m/%d/%Y %I:%M:%S %p"
)
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)


def get_next_wednesday(starting_date: datetime) -> str:
    """Return the date of the next Wednesday in YYYY-MM-DD format."""

    current_day_of_week = starting_date.weekday()
    days_until_wednesday = (2 - current_day_of_week + 7) % 7
    if days_until_wednesday == 0:
        days_until_wednesday = 7

    next_wednesday = starting_date + timedelta(days=days_until_wednesday)
    return next_wednesday.strftime("%Y-%m-%d")


def main(round_id: str, clade_output_path: Path):
    """Get a list of clades to model and save to the hub's auxiliary-data folder."""

    round_data: defaultdict[str, dict] = defaultdict(dict)

    # Get the clade list
    clade_list = get_clade_list.main()
    clade_list.sort()
    clade_list.append("other")
    round_data["clades"] = clade_list
    logger.info(f"Clade list: {clade_list}")

    # Get metadata about the Nextstrain ncov pipeline run that
    # the clade list is based on
    ct = CladeTime()
    ncov_meta = ct.ncov_metadata
    ncov_meta["metadata_version_url"] = ct.url_ncov_metadata
    round_data["meta"]["ncov"] = ncov_meta
    logger.info(f"Ncov metadata: {ncov_meta}")

    clade_file = clade_output_path / f"{round_id}.json"
    with open(clade_file, "w") as f:
        json.dump(round_data, f, indent=4)

    logger.info(f"Clade list saved: {clade_file}")


if __name__ == "__main__":
    # round_id will be the Wednesday following the creation of the clade list
    round_id = get_next_wednesday(datetime.today())
    clade_output_path = Path(__file__).parents[1] / "auxiliary-data" / "modeled-clades"
    main(round_id, clade_output_path)
