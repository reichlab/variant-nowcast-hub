"""
Aggregate clade counts by location and collection date and save the result to the hub's auxiliary-data folder.

This uses the cladetime package's CladeTime class, which provides a wrapper around GenBank-based
Sars-CoV-2 files provided by NextStrain.
https://github.com/reichlab/cladetime

The script is scheduled to run every Wednesday, after a modeling round closes.

To run the script manually:
1. Install uv on your machine: https://docs.astral.sh/uv/getting-started/installation/
2. From the root of this repo: uv run --with-requirements src/requirements.txt src/get_location_date_counts.py --nowcast-date=YYYY-MM-DD

To run the included tests manually (from the root of the repo):
uv run --with-requirements src/requirements.txt --module pytest src/get_location_date_counts.py
"""

import logging
import os
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import click
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


@click.command()
@click.option(
    "--nowcast-date",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    required=True,
    help="The modeling round nowcast date (i.e., round_id) (YYYY-MM-DD)",
)
@click.option(
    "--output-path",
    type=Path,
    required=False,
    default=Path(__file__).parents[1] / "auxiliary-data" / "unscored-location-dates",
    help="For testing only: Path object to the directory where the output file will be saved",
)
def main(nowcast_date: datetime, output_path: Path):
    # Round closing time is 8 PM US/Eastern on the day the round closes
    round_close_time = nowcast_date.replace(hour=20, minute=0, second=0)
    round_close_time = round_close_time.replace(tzinfo=ZoneInfo("US/Eastern"))
    nowcast_date_str = nowcast_date.strftime("%Y-%m-%d")

    logger.info(f"Getting location/date counts for round {nowcast_date_str}")
    location_date_df = get_location_date_counts(round_close_time)

    output_file = output_path / f"{nowcast_date_str}.csv"
    location_date_df.write_csv(output_file)
    logger.info(f"Location/date counts saved to {output_file}")


def get_location_date_counts(round_close_time: datetime) -> pl.DataFrame:
    """
    Return a Polars DataFrame with total clade counts by location and collection date.
    The DataFrame will have a column for each date 31 days prior to round close.
    """

    # CladeTime object expects a UTC datetime
    round_close_utc = round_close_time.astimezone(ZoneInfo("UTC"))
    ct = CladeTime(sequence_as_of=round_close_utc)

    # CladeTime objects provide a Polars LazyFrame reference to
    # Nextstrain's SARS-CoV-2 Genbank sequence metadata.
    sequence_metadata = ct.sequence_metadata

    # Apply the same filters we used to create the list of clade
    # target data for the round (e.g., USA, human host)
    filtered = sequence.filter_metadata(sequence_metadata)

    # Create a LazyFrame with all combinations of states and the
    # dates we're interested in (in this case, 31 days prior to
    # round close)
    end_date = round_close_time.date()
    begin_date = end_date - timedelta(days=31)
    dates_and_locations = pl.LazyFrame(
        pl.date_range(begin_date, end_date, "1d", eager=True).alias("date")
    ).join(filtered.select("location").unique(), how="cross")

    # Group and count sequence metadata
    grouped = (
        filtered.select(["location", "date", "clade"])
        .group_by("location", "date")
        .agg(pl.len().alias("count"))
    )

    # Add rows that for states and dates that didn't appear in the past 31 days
    grouped_all = (
        dates_and_locations.join(grouped, on=["location", "date"], how="left")
        .fill_null(strategy="zero")
        .sort("location")
        .rename({"date": "target_date"})
    )

    return grouped_all.collect(streaming=True)


def test_get_location_date_counts(monkeypatch):
    """Run checks on location/date clade counts."""

    # Patch the CLADETIME_DEMO environment variable so the test will
    # run against Nextstrain's 100k sample dataset instead of a full dataset.
    envs = {"CLADETIME_DEMO": "true"}
    monkeypatch.setattr(os, "environ", envs)

    round_close_test_time = datetime(
        2024, 11, 6, 20, 0, 0, tzinfo=ZoneInfo("US/Eastern")
    )
    computed_counts = get_location_date_counts(round_close_test_time)

    # Pull the same set of sequence metadata from Nextstrain, filter by date,
    # and compare overall record count to the one produced by get_location_date_counts
    ct = CladeTime(sequence_as_of=round_close_test_time.astimezone(ZoneInfo("UTC")))
    begin_date = round_close_test_time.date() - timedelta(days=31)
    test_data = sequence.filter_metadata(ct.sequence_metadata)
    test_data = test_data.filter(pl.col("date") >= begin_date).collect()

    assert test_data.height == computed_counts["count"].sum()


if __name__ == "__main__":
    # Until there's a Python version of hubData, get the current round ID from the latest
    # .json file in auxiliary-data/modeled-clades
    modeled_clades_path = (
        Path(__file__).parents[1] / "auxiliary-data" / "modeled-clades"
    )
    all_files = os.listdir(modeled_clades_path)
    date_files = [f for f in all_files if f[4] == "-" and f[7] == "-" and "json" in f]
    date_files.sort(reverse=True)
    round_id = date_files[0].split(".")[0]

    output_path = (
        Path(__file__).parents[1] / "auxiliary-data" / "unscored-location-dates"
    )
    main()
