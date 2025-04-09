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
2. From the root of this repo: uv run --with-requirements src/requirements.txt src/get_clades_to_model.py

To run the included tests manually (from the root of the repo):
uv run --with-requirements src/requirements.txt --module pytest src/get_clades_to_model.py
"""

import os
import json
import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from itertools import chain, repeat
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
    filtered_metadata: pl.LazyFrame,
    threshold: float,
    threshold_weeks: int,
    max_clades: int,
) -> list[str]:
    """Get a list of clades to forecast."""

    clade_counts = sequence.summarize_clades(
        filtered_metadata, group_by=["clade", "date", "location"]
    )

    # Based on the most recent sequence collection date and the threshold_weeks parameter,
    # determine the minimum sequence collection date to consider when generating the clade list.
    # Inclusion Criteria: At least 2 sequences (across all weeks).
    max_day = clade_counts.select(pl.max("date")).collect().item()
    threshold_sundays_ago = max_day - timedelta(
        # include max_day.weekday() because the week of the most recent collection date
        # is not counted as part of the threshold_weeks
        days=max_day.weekday() + 7 * (threshold_weeks)
    )

    # combine states and summarize clade counts over weeks, limiting to
    # collection dates within the specified number of threshold weeks
    lf = (
        clade_counts.filter(pl.col("date") >= threshold_sundays_ago)
        .sort("date")
        .group_by_dynamic("date", every="1w", start_by="sunday", group_by="clade")
        .agg(pl.col("count").sum())
    )

    # create a separate frame that combines clades and summarizes total sequence counts per week
    total_counts = lf.group_by("date").agg(pl.col("count").sum().alias("total_count"))

    # join with count data to add a total counts per day column
    prop_dat = lf.join(total_counts, on="date").with_columns(
        (pl.col("count") / pl.col("total_count")).alias("proportion")
    )

    # Filter clades that appear at least twice in last threshold_sundays_ago weeks
    filtered_clades = (
        prop_dat.group_by('clade')
        .agg(pl.col("count").sum().alias("date_counts"))
        .filter(pl.col("date_counts") >= 2)
        .collect()
    )

    # Get list of clades from above filter
    filtered_clades = pl.Series(filtered_clades.select('clade')).to_list()

    # Select only clades from above
    prop_dat = prop_dat.filter(
        pl.col("clade").is_in(filtered_clades)
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

    # sort clade list before returning
    variants.sort()

    return variants


def get_metadata(ct: CladeTime, current_time: str) -> dict[str, dict | str]:
    """Create metadata to store with the clade list."""
    metadata: dict[str, dict | str] = dict(created_at=current_time)

    ncov_metadata = ct.ncov_metadata
    ncov_metadata["metadata_version_url"] = ct.url_ncov_metadata
    metadata["ncov"] = ncov_metadata

    return metadata


def main(
    round_id: str,
    clade_output_path: Path,
    threshold: float = 0.01,
    threshold_weeks: int = 3,
    max_clades: int = 9,
) -> Path:
    """Get a list of clades to model and save to the hub's auxiliary-data folder."""

    class RoundData(TypedDict):
        clades: list[str]
        meta: dict[str, dict | str]

    current_time = datetime.now(timezone.utc).isoformat(timespec="seconds")

    # Get the clade list
    logger.info("Getting clade list")
    ct = CladeTime()
    lf_metadata = ct.sequence_metadata
    lf_metadata_filtered = sequence.filter_metadata(lf_metadata)

    clade_list = get_clades(
        lf_metadata_filtered, threshold, threshold_weeks, max_clades
    )

    # Sort clade list and add "other"
    clade_list.append("other")
    logger.info(f"Clade list: {clade_list}")

    # Get metadata about the Nextstrain ncov pipeline run that
    # the clade list is based on
    metadata = get_metadata(ct, current_time)
    logger.info(f"Round open metadata: {metadata}")

    round_data: RoundData = {
        "clades": clade_list,
        "meta": metadata,
    }

    clade_file = clade_output_path / f"{round_id}.json"
    with open(clade_file, "w") as f:
        json.dump(round_data, f, indent=4)

    logger.info(f"Clade list saved: {clade_file}")
    return clade_file


if __name__ == "__main__":
    # round_id will be the Wednesday following the creation of the clade list
    round_id = get_next_wednesday(datetime.today())
    clade_output_path = Path(__file__).parents[1] / "auxiliary-data" / "modeled-clades"
    main(round_id, clade_output_path)


##############################################################
# Tests                                                      #
##############################################################


def get_test_data() -> pl.LazyFrame:
    test_rows = 15
    states = ["MA", "PA", "TX"]
    dates = [date(2025, 2, 1), date(2025, 2, 12), date(2025, 2, 19)]
    test_data = pl.DataFrame(
        {
            "clade": chain(
                ["23A"], repeat("24E", 4), repeat("24F", 5), repeat("25A", 5)
            ),
            "country": ["USA"] * test_rows,
            "date": [dates[i % len(dates)] for i in range(test_rows)],
            "strain": [uuid.uuid4() for n in range(0, test_rows)],
            "host": ["Homo sapiens"] * test_rows,
            "location": [states[i % len(states)] for i in range(test_rows)],
        }
    ).lazy()

    return test_data


def test_get_clades_default_criteria():
    """Test default clade inclusion criteria."""
    test_data = get_test_data()
    threshold = 0.01
    threshold_weeks = 3
    max_clades = 9

    clade_list = get_clades(test_data, threshold, threshold_weeks, max_clades)
    assert clade_list == ["24E", "24F", "25A"]


def test_get_clades_smaller_max():
    """Test smaller max_clades parameter."""
    test_data = get_test_data()
    threshold = 0.01
    threshold_weeks = 3
    max_clades = 2

    clade_list = get_clades(test_data, threshold, threshold_weeks, max_clades)
    assert clade_list == ["24F", "25A"]


def test_get_clades_adjust_threshold_weeks():
    """Test a smaller threshold_weeks parameter."""
    test_data = get_test_data()
    max_clades = 9
    threshold = 0.01
    threshold_weeks = 2

    clade_list = get_clades(test_data, threshold, threshold_weeks, max_clades)
    assert clade_list == ["24E", "24F", "25A"]


def test_get_clades_adjust_threshold():
    """Test a larger proportion threshold parameter."""
    test_data = get_test_data()
    max_clades = 9
    threshold = 0.3
    threshold_weeks = 3

    clade_list = get_clades(test_data, threshold, threshold_weeks, max_clades)
    assert clade_list == ["24E", "24F", "25A"]


def test_metadata():
    """Test that round open metadata is correct."""
    current_time = datetime(2025, 2, 24, 2, 16, 22, tzinfo=timezone.utc).isoformat(
        timespec="seconds"
    )
    round_open_date = datetime(2025, 2, 24)
    ct = CladeTime(round_open_date)

    meta = get_metadata(ct, current_time)
    ncov_metadata = meta.get("ncov", {})

    assert meta.get("created_at") == current_time
    assert ncov_metadata.get("nextclade_dataset_version") == "2025-01-28--16-39-09Z"
    assert ncov_metadata.get("nextclade_version_num") == "3.10.1"


def test_end_to_end(monkeypatch, tmp_path):
    """Test end-to-end functionality."""
    round_id = "2025-02-26"
    clade_file = main(round_id, tmp_path)
    # Patch the CLADETIME_DEMO environment variable so the test will
    # run against Nextstrain's 100k sample dataset instead of a full dataset.
    envs = {"CLADETIME_DEMO": "true"}
    monkeypatch.setattr(os, "environ", envs)

    assert clade_file.name == f"{round_id}.json"
    with open(clade_file, "r", encoding="utf-8") as f:
        clade_dict = json.loads(f.read())
    clade_list = clade_dict.get("clades", [])

    # last item on list of clades to model should be "other"
    assert clade_list[-1] == "other"
