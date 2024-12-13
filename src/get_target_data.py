"""
Create time series and oracle output target data for a specfici modeling round.

This script wraps the cladetime package, which generates clade counts using the
GenBank-based Sars-CoV-2 sequence metadata from Nextstrain.
https://github.com/reichlab/cladetime

The script is scheduled to run every Wednesday evening (US Eastern)

To run the script manually:
1. Install uv on your machine: https://docs.astral.sh/uv/getting-started/installation/
2. From the root of this repo:
uv run src/get_target_data.py --nowcast-date=YYYY-MM-DD
For example:
uv run src/get_target_data.py --nowcast-date=2024-10-09
"""

# /// script
# requires-python = "==3.12"
# dependencies = [
#   "click",
#   "cladetime@git+https://github.com/reichlab/cladetime@bsweger/optimize-fasta-handling/55",
#   "polars>=1.17.1,<1.18.0",
# ]
# ///

import json
from pathlib import Path
import logging
from datetime import datetime, timedelta, timezone

import click
import polars as pl

from cladetime import Clade, CladeTime, sequence  # type: ignore

# Log to stdout
logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s -  %(levelname)s - %(message)s", datefmt="%m/%d/%Y %I:%M:%S %p"
)
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Output directory is the hub's target-data directory
# (note in the docstring that this script should be run from the repo's root)
target_data_dir = Path(__file__).parents[1] / "target-data"
target_time_series_dir = target_data_dir / "time-series"
target_time_series_dir.mkdir(exist_ok=True, parents=True)


def normalize_date(ctx, param, value):
    """Set a datetime value to end of day UTC."""
    if value is not None:
        value = value.replace(hour=23, minute=59, second=59, tzinfo=timezone.utc)
    return value


def set_sequence_as_of(ctx, param, value):
    """Set the sequence_as_of default value to nowcast_date + 90 days."""
    if value is None:
        nowcast_date = ctx.params.get("nowcast_date")
        value = nowcast_date + timedelta(days=90)
    value = value.replace(hour=23, minute=59, second=59, tzinfo=timezone.utc)
    return value


def set_collection_min_date(ctx, param, value):
    """Set the collection_min_date default value to nowcast date minus 31 days."""
    if value is None:
        nowcast_date = ctx.params.get("nowcast_date")
        value = nowcast_date + timedelta(days=-31)
    value = value.replace(hour=23, minute=59, second=59, tzinfo=timezone.utc)
    return value


def set_collection_max_date(ctx, param, value):
    """Set the collection_max_date default value to nowcast date plus 10 days."""
    if value is None:
        nowcast_date = ctx.params.get("nowcast_date")
        value = nowcast_date + timedelta(days=10)
    value = value.replace(hour=23, minute=59, second=59, tzinfo=timezone.utc)
    return value


@click.command()
@click.option(
    "--nowcast-date",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    required=True,
    help="The modeling round nowcast date (i.e., round_id) (YYYY-MM-DD). The tree as of date is set to this reference date minus two days.",
)
@click.option(
    "--sequence-as-of",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    required=False,
    default=None,
    callback=set_sequence_as_of,
    help="Get counts based on the last available Nextstrain sequence metadata on or prior to this UTC date (YYYY-MM-DD). Default is the nowcast date + 90 days.",
)
@click.option(
    "--tree-as-of",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    required=False,
    default=None,
    callback=normalize_date,
    help="Use this UTC date to retrieve the reference tree used for clade assignment (YYYY-MM-DD). Defaults to created_at in the round's modeled-clades file.",
)
@click.option(
    "--collection-min-date",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    required=False,
    default=None,
    callback=set_collection_min_date,
    help="Assign clades to sequences collected on or after this UTC date (YYYY-MM-DD). Default is the nowcast date minus 31 days.",
)
@click.option(
    "--collection-max-date",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    required=False,
    default=None,
    callback=set_collection_max_date,
    help="Assign clades to sequences collected on or before this UTC date (YYYY-MM-DD), Default is the nowcast date plus 10 days.",
)
def main(
    nowcast_date: datetime,
    sequence_as_of: datetime,
    tree_as_of: datetime,
    collection_min_date: datetime,
    collection_max_date: datetime,
) -> Clade:
    """Get clade counts and save to S3 bucket."""

    # Date for retrieving sequences cannot be in the future
    if sequence_as_of > datetime.now(tz=timezone.utc):
        logger.info(
            f"Stopping script. Sequence_as_of is in the future: {sequence_as_of}"
        )
        return 1

    # Nowcast_date must match a variant-nowcast-hub round_id
    nowcast_string = nowcast_date.strftime("%Y-%m-%d")
    modeled_clades_path = (
        Path("auxiliary-data/modeled-clades") / f"{nowcast_string}.json"
    )
    if not modeled_clades_path.is_file():
        logger.info(
            f"Stopping script. No round found for nowcast_date: {nowcast_string}"
        )
        return 1
    else:
        modeled_clades = json.loads(modeled_clades_path.read_text(encoding="utf-8"))
        clade_list = modeled_clades.get("clades", [])

    if tree_as_of is None:
        if "created_at" not in modeled_clades.get("meta", {}):
            logger.info(
                f"No created_at field in modeled_clades metadata for {nowcast_string}. Defaulting to nowcast_date - 2 days."
            )
            tree_as_of = (nowcast_date - timedelta(days=2)).replace(
                hour=23, minute=59, second=59, tzinfo=timezone.utc
            )
        else:
            tree_as_of = datetime.fromisoformat(modeled_clades["meta"]["created_at"])

    assignments = assign_clades(
        nowcast_date,
        sequence_as_of,
        tree_as_of,
        collection_min_date,
        collection_max_date,
    )
    write_target_time_series(
        assignments,
        clade_list,
        nowcast_string,
        sequence_as_of.strftime("%Y-%m-%d"),
        collection_min_date,
        collection_max_date,
    )


def assign_clades(
    nowcast_date: datetime,
    sequence_as_of: datetime,
    tree_as_of: datetime,
    collection_min_date: datetime,
    collection_max_date: datetime,
) -> Clade:
    # Instantiate CladeTime object
    ct = CladeTime(sequence_as_of=sequence_as_of, tree_as_of=tree_as_of)
    logger.info(
        {
            "msg": "Starting clade assignment",
            "CladeTime": ct,
            "nowcast_date": nowcast_date.isoformat(timespec="seconds"),
            "nextstrain_metadata_url": ct.url_sequence_metadata,
            "collection_min_date": collection_min_date.isoformat(timespec="seconds"),
            "collection_max_date": collection_max_date.isoformat(timespec="seconds"),
        }
    )

    filtered_metadata = sequence.filter_metadata(
        ct.sequence_metadata,
        collection_min_date=collection_min_date,
        collection_max_date=collection_max_date,
    )

    assignments = ct.assign_clades(filtered_metadata)
    logger.info("Clade assignments complete")

    return assignments


def write_target_time_series(
    assignments: Clade,
    clade_list: list,
    nowcast_string: str,
    sequence_as_of_string: str,
    collection_min_date: datetime,
    collection_max_date: datetime,
):
    """Write time series target data to partitioned parquet file."""
    time_series = assignments.summary.select(
        ["location", "date", "clade_nextstrain", "count"]
    ).filter(pl.col("clade_nextstrain").is_in(clade_list))

    all_rows = (
        pl.LazyFrame(
            pl.date_range(
                collection_min_date, collection_max_date, "1d", eager=True
            ).alias("date")
        )
        .join(time_series.select("location").unique(), how="cross")
        .join(time_series.select("clade_nextstrain").unique(), how="cross")
    )

    # Add rows that for locations/target_dates/clades that didn't have observations
    time_series_all = (
        all_rows.join(
            time_series, on=["location", "date", "clade_nextstrain"], how="left"
        )
        .fill_null(strategy="zero")
        .rename(
            {
                "clade_nextstrain": "clade",
                "count": "observation",
                "date": "target_date",
            }
        )
    )

    output_path = (
        target_time_series_dir
        / f"nowcast_date={nowcast_string}/sequence_as_of={sequence_as_of_string}"
    )
    output_path.mkdir(exist_ok=True, parents=True)

    # the time_series_all LazyFrame has a query plan that sink_parquet doesn't like,
    # so we'll have to collect it before exporting as parquet
    time_series_all.collect().write_parquet(output_path / "timeseries.parquet")
    logger.info(f"Target time series saved to {output_path / 'timeseries.parquet'}")


if __name__ == "__main__":
    main()
