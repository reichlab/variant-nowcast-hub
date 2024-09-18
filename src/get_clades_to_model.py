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
2. From the repo's /src directory: uv run get_clades_to_model.py
"""

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "virus_clade_utils@git+https://github.com/reichlab/virus-clade-utils/",
# ]
# ///

import logging
from datetime import datetime, timedelta
from pathlib import Path

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

    clade_list = get_clade_list.main()
    clade_list.sort()
    logger.info(f"Clade list: {clade_list}")

    clade_file = clade_output_path / f"{round_id}.txt"
    with open(clade_file, "w") as f:
        for clade in clade_list:
            f.write(f"{clade}\n")
        f.write("other\n")

    logger.info(f"Clade list saved: {clade_file}")


if __name__ == "__main__":
    # round_id will be the Wednesday following the creation of the clade list
    round_id = get_next_wednesday(datetime.today())
    clade_output_path = Path(__file__).parents[1] / "auxiliary-data" / "modeled-clades"
    main(round_id, clade_output_path)
