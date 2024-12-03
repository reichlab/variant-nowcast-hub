"""
Create a list of Sars-CoV-2 clades to model and saves it to the hub's auxiliary-data folder.

This script wraps the cladetime package, which generates the clade list using the
latest GenBank-based Sars-CoV-2 sequence metadata from Nextstrain.
https://github.com/reichlab/cladetime

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
#   "cladetime@git+https://github.com/reichlab/cladetime",
#   "polars",
# ]
# ///

import json
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import TypedDict

import polars as pl
from cladetime import CladeTime, sequence  # type: ignore

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


def get_clades(
    clade_counts: pl.LazyFrame, threshold: float, threshold_weeks: int, max_clades: int
) -> list[str]:
    """Get a list of clades to forecast."""

    # based on the data's most recent date, get the week start three weeks ago (not including this week)
    max_day = clade_counts.select(pl.max("date")).collect().item()
    threshold_sundays_ago = max_day - timedelta(
        days=max_day.weekday() + 7 * (threshold_weeks)
    )

    # sum over weeks, combine states, and limit to just the past 3 weeks (not including current week)
    lf = (
        clade_counts.filter(pl.col("date") >= threshold_sundays_ago)
        .sort("date")
        .group_by_dynamic("date", every="1w", start_by="sunday", group_by="clade")
        .agg(pl.col("count").sum())
    )

    # create a separate frame with the total counts per week
    total_counts = lf.group_by("date").agg(pl.col("count").sum().alias("total_count"))

    # join with count data to add a total counts per day column
    prop_dat = lf.join(total_counts, on="date").with_columns(
        (pl.col("count") / pl.col("total_count")).alias("proportion")
    )

    # retrieve list of variants which have crossed the threshold over the past threshold_weeks
    high_prev_variants = (
        prop_dat.filter(pl.col("proportion") > threshold)
        .select("clade")
        .unique()
        .collect()
    )

    # if more than the specified number of clades cross the threshold,
    # take the clades with the largest counts over the past threshold_weeks
    # (if there's a tie, take the first clade alphabetically)
    if len(high_prev_variants) > max_clades:
        high_prev_variants = (
            prop_dat.group_by("clade")
            .agg(pl.col("count").sum())
            .sort("count", "clade", descending=[True, False])
            .collect()
        )

    variants = high_prev_variants.get_column("clade").to_list()[:max_clades]

    return variants


def main(
    round_id: str,
    clade_output_path: Path,
    threshold: float = 0.01,
    threshold_weeks: int = 3,
    max_clades: int = 9,
):
    """Get a list of clades to model and save to the hub's auxiliary-data folder."""

    class RoundData(TypedDict):
        clades: list[str]
        meta: dict[str, dict]

    # Get the clade list
    logger.info("Getting clade list")
    ct = CladeTime()
    lf_metadata = ct.sequence_metadata
    lf_metadata_filtered = sequence.filter_metadata(lf_metadata)
    counts = sequence.summarize_clades(
        lf_metadata_filtered, group_by=["clade", "date", "location"]
    )
    clade_list = get_clades(counts, threshold, threshold_weeks, max_clades)

    # Sort clade list and add "other"
    clade_list.sort()
    clade_list.append("other")
    logger.info(f"Clade list: {clade_list}")

    # Get metadata about the Nextstrain ncov pipeline run that
    # the clade list is based on
    ncov_meta = ct.ncov_metadata
    ncov_meta["metadata_version_url"] = ct.url_ncov_metadata
    logger.info(f"Ncov metadata: {ncov_meta}")

    round_data: RoundData = {"clades": clade_list, "meta": {"ncov": ncov_meta}}

    clade_file = clade_output_path / f"{round_id}.json"
    with open(clade_file, "w") as f:
        json.dump(round_data, f, indent=4)

    logger.info(f"Clade list saved: {clade_file}")


if __name__ == "__main__":
    # round_id will be the Wednesday following the creation of the clade list
    round_id = get_next_wednesday(datetime.today())
    clade_output_path = Path(__file__).parents[1] / "auxiliary-data" / "modeled-clades"
    main(round_id, clade_output_path)
