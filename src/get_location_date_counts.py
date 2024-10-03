"""
Aggregate clade counts by location and collection date and save the result to the hub's auxiliary-data folder.

This uses the virus-clade-utils package's CladeTime object, which provides a wrapper around GenBank-based
Sars-CoV-2 files provided by NextStrain.
https://github.com/reichlab/virus-clade-utils

The script is scheduled to run every Wednesday, after a modeling round closes.

To run the script manually:
1. Install uv on your machine: https://docs.astral.sh/uv/getting-started/installation/
2. From the root of this repo: uv run src/get_location_date_counts.py
"""

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "virus_clade_utils@git+https://github.com/reichlab/virus-clade-utils@bsweger/sequence-by-state-date/50"
# ]
# ///

import os
from datetime import datetime, timedelta
from pathlib import Path

import polars as pl
from virus_clade_utils.cladetime import CladeTime  # type: ignore
from virus_clade_utils.util.sequence import filter_covid_genome_metadata  # type: ignore


def main(round_id: str, output_path: Path):
    # Get a CladeTime object for the most recent Nextstrain sequence metadata
    ct = CladeTime()

    # CladeTime objects provide a Polars LazyFrame reference to
    # Nextstrain's SARS-CoV-2 Genbank sequence metadata.
    sequence_metadata = ct.sequence_metadata

    # Apply the same filters we used to create the list of clade
    # target data for the round (e.g., USA, human host)
    filtered = filter_covid_genome_metadata(sequence_metadata)

    # Create a LazyFrame with all combinations of states and the
    # dates we're interested in (in this case, 31 days prior to
    # the round's nowcast date)
    end_date = datetime.strptime(round_id, "%Y-%m-%d").date()
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
    grouped_all = dates_and_locations.join(grouped, on=["location", "date"], how="left")

    # Pivot to make each date a column
    pivot = (
        grouped_all.collect()
        .pivot(
            "date",
            index="location",
            values="count",
            aggregate_function="sum",
            sort_columns=True,
        )
        .fill_null(strategy="zero")
        .sort("location")
    )

    pivot.write_csv(output_path / f"{round_id}.csv")


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
        Path(__file__).parents[1] / "auxiliary-data" / "unscore-location-dates"
    )
    main(round_id, output_path)
