"""
Create time series and oracle output target data for a specific modeling round.

This script wraps the cladetime package, which generates clade counts using the
GenBank-based Sars-CoV-2 sequence metadata from Nextstrain.
https://github.com/reichlab/cladetime

The script is scheduled to run every Wednesday evening (US Eastern)

To run the script manually:
1. Install uv on your machine: https://docs.astral.sh/uv/getting-started/installation/
2. From the root of this repo:
uv run src/get_target_data.py --nowcast-date=YYYY-MM-DD
For example:
`uv run src/get_target_data.py --nowcast-date=2024-10-09`

To run the included tests manually (from the root of the repo):
uv run --with-requirements src/requirements.txt --module pytest src/get_target_data.py
"""

# /// script
# requires-python = "==3.12"
# dependencies = [
#   "click",
#   "cladetime@git+https://github.com/reichlab/cladetime",
#   "polars>=1.17.1,<1.18.0",
# ]
# ///

import json
from pathlib import Path
import logging
import sys
from datetime import date, datetime, timedelta, timezone

import click
import polars as pl
from click.testing import CliRunner
from click import Context, Option

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

# valid locations for variant-nowcast-hub (50 states + DC and PR)
state_list = [
    "AL",
    "AK",
    "AZ",
    "AR",
    "CA",
    "CO",
    "CT",
    "DE",
    "DC",
    "FL",
    "GA",
    "HI",
    "ID",
    "IL",
    "IN",
    "IA",
    "KS",
    "KY",
    "LA",
    "ME",
    "MD",
    "MA",
    "MI",
    "MN",
    "MS",
    "MO",
    "MT",
    "NE",
    "NV",
    "NH",
    "NJ",
    "NM",
    "NY",
    "NC",
    "ND",
    "OH",
    "OK",
    "OR",
    "PA",
    "RI",
    "SC",
    "SD",
    "TN",
    "TX",
    "UT",
    "VT",
    "VA",
    "WA",
    "WV",
    "WI",
    "WY",
    "PR",
]


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
@click.option(
    "--target-data-dir",
    type=Path,
    required=False,
    default=Path(__file__).parents[1] / "target-data",
    help="For testing only: Path object to the directory where the target data will be saved. Default is the hub's target-data directory.",
)
def main(
    nowcast_date: datetime,
    sequence_as_of: datetime,
    tree_as_of: datetime,
    collection_min_date: datetime,
    collection_max_date: datetime,
    target_data_dir: Path,
) -> tuple[Path, Path]:
    """Get clade counts and save to S3 bucket."""

    # Date for retrieving sequences cannot be in the future
    if sequence_as_of > datetime.now(tz=timezone.utc):
        logger.info(
            f"Stopping script. Sequence_as_of is in the future: {sequence_as_of}"
        )
        sys.exit(1)

    # Nowcast_date must match a variant-nowcast-hub round_id
    nowcast_string = nowcast_date.strftime("%Y-%m-%d")
    modeled_clades_path = (
        Path("auxiliary-data/modeled-clades") / f"{nowcast_string}.json"
    )
    if not modeled_clades_path.is_file():
        logger.info(
            f"Stopping script. No round found for nowcast_date: {nowcast_string}"
        )
        sys.exit(1)
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
    target_data = create_target_data(
        assignments,
        clade_list,
        nowcast_string,
        sequence_as_of.strftime("%Y-%m-%d"),
        collection_min_date,
        collection_max_date,
    )

    output_files = write_target_data(
        nowcast_string,
        sequence_as_of.strftime("%Y-%m-%d"),
        target_data,
        target_data_dir,
    )

    return output_files


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


def create_target_data(
    assignments: Clade,
    clade_list: list,
    nowcast_string: str,
    sequence_as_of_string: str,
    collection_min_date: datetime,
    collection_max_date: datetime,
) -> tuple[pl.LazyFrame, pl.LazyFrame]:
    """Return time series and oracle output target data."""

    time_series = (
        assignments.summary.select(["location", "date", "clade_nextstrain", "count"])
        .with_columns(
            clade=pl.when(pl.col("clade_nextstrain").is_in(clade_list))
            .then(pl.col("clade_nextstrain"))
            .otherwise(pl.lit("other"))
        )
        .select(["location", "date", "clade", "count"])
        .group_by(["location", "date", "clade"])
        .sum()
    )

    all_rows = (
        pl.LazyFrame(
            pl.date_range(
                collection_min_date, collection_max_date, "1d", eager=True
            ).alias("date")
        )
        .join(pl.Series("location", state_list).to_frame().lazy(), how="cross")
        .join(pl.Series("clade", clade_list).to_frame().lazy(), how="cross")
    )

    # Add rows that for locations/target_dates/clades that didn't have observations
    time_series_all = (
        all_rows.join(time_series, on=["location", "date", "clade"], how="left")
        .fill_null(strategy="zero")
        .rename(
            {
                "count": "observation",
                "date": "target_date",
            }
        )
    )

    oracle_output = (
        time_series_all.select(["location", "target_date", "clade", "observation"])
        .with_columns(pl.lit(nowcast_string).alias("nowcast_date"))
        .rename({"observation": "oracle_value"})
    )

    return (time_series_all, oracle_output)


def write_target_data(
    nowcast_string: str,
    sequence_as_of_string: str,
    target_data: tuple[pl.LazyFrame, pl.LazyFrame],
    # default output directory is the hub's target-data directory
    target_data_dir: Path,
) -> tuple[Path, Path]:
    """Write time series and oracle output target data."""

    # write time series data
    target_time_series_dir = target_data_dir / "time-series"

    ts_output_path = (
        target_time_series_dir
        / f"nowcast_date={nowcast_string}/sequence_as_of={sequence_as_of_string}"
    )
    ts_output_path.mkdir(exist_ok=True, parents=True)
    ts_output_path = ts_output_path / "timeseries.parquet"

    # the time_series LazyFrame has a query plan that sink_parquet doesn't like,
    # so we'll have to collect it before exporting as parquet
    time_series = target_data[0]
    time_series.collect().write_parquet(ts_output_path)
    logger.info(f"Target time series saved to {ts_output_path}")

    # write oracle output data
    target_oracle_output_dir = target_data_dir / "oracle-output"
    oracle_output_path = target_oracle_output_dir / f"nowcast_date={nowcast_string}"
    oracle_output_path.mkdir(exist_ok=True, parents=True)
    oracle_output_path = oracle_output_path / "oracle.parquet"

    oracle = target_data[1]
    oracle.collect().write_parquet(oracle_output_path)
    logger.info(f"Target oracle output saved to {oracle_output_path}")

    return (ts_output_path, oracle_output_path)


if __name__ == "__main__":
    main()


##############################################################
# Tests                                                      #
##############################################################


def test_set_option_defaults():
    """Test default value of optional Click parameters."""

    @click.command()
    def mock_command():
        pass

    ctx = Context(mock_command)
    ctx.params = {"nowcast_date": datetime(2024, 10, 2)}

    # default sequence_as_of is 90 days after the nowcast date
    param = Option(["--sequence-as-of"])
    result = set_sequence_as_of(ctx, param, None)
    assert result == datetime(2024, 12, 31, 23, 59, 59, tzinfo=timezone.utc)

    # if tree_as_of is provided, it should be set to end of day UTC
    param = Option(["--tree-as-of"])
    result = normalize_date(ctx, param, datetime(2024, 11, 11, 11, 11, 11))
    assert result == datetime(2024, 11, 11, 23, 59, 59, tzinfo=timezone.utc)

    # default collection_min_date is 31 days before the nowcast date
    param = Option(["--collection-min-date"])
    result = set_collection_min_date(ctx, param, None)
    assert result == datetime(2024, 9, 1, 23, 59, 59, tzinfo=timezone.utc)

    # default collection_max_date is 10 days after the nowcast date
    param = Option(["--collection-max-date"])
    result = set_collection_max_date(ctx, param, None)
    assert result == datetime(2024, 10, 12, 23, 59, 59, tzinfo=timezone.utc)


def test_bad_inputs():
    """Bad inputs should return a non-zero exit code."""
    runner = CliRunner()

    # sequence_as_of cannot be in the future
    with runner.isolated_filesystem():
        result = runner.invoke(
            main,
            [
                "--nowcast-date",
                "2024-10-02",
                "--sequence-as-of",
                "2054-10-02",
            ],
            catch_exceptions=True,
            color=True,
            standalone_mode=False,
        )
        assert result.exit_code == 1

    # nowcast_date must match a variant-nowcast-hub round_id
    with runner.isolated_filesystem():
        result = runner.invoke(
            main,
            [
                "--nowcast-date",
                "2022-2-2",
                "--sequence-as-of",
                "2024-10-01",
            ],
            catch_exceptions=True,
            color=True,
            standalone_mode=False,
        )
        assert result.exit_code == 1


def test_target_data():
    test_summary = {
        "location": ["PA", "PA", "MA", "MA", "MA"],
        "date": [
            date(2024, 12, 1),
            date(2024, 12, 3),
            date(2024, 12, 2),
            date(2024, 12, 1),
            date(2024, 12, 2),
        ],
        "clade_nextstrain": ["AA", "BB", "CC", "DD", "BB"],
        "count": [2, 3, 4, 5, 6],
    }
    test_assignments: Clade = Clade({}, pl.LazyFrame(), pl.LazyFrame(test_summary))  # type: ignore
    test_clade_list = ["AA", "BB", "other"]
    test_min_date = datetime(2024, 11, 30, tzinfo=timezone.utc)
    test_max_date = datetime(2024, 12, 4, tzinfo=timezone.utc)
    time_series, oracle = create_target_data(
        test_assignments,
        test_clade_list,
        "2024-12-11",
        "2024-12-11",
        test_min_date,
        test_max_date,
    )
    ts = time_series.collect()

    # time series row count should = 5 days * 3 clades * 52 locations
    assert ts.height == 5 * 3 * 52

    expected_time_series_cols = set(["location", "target_date", "clade", "observation"])
    assert set(ts.columns) == expected_time_series_cols

    assert set(ts.get_column("clade").to_list()) == {"AA", "BB", "other"}
    assert ts.get_column("target_date").min() == date(2024, 11, 30)
    assert ts.get_column("target_date").max() == date(2024, 12, 4)
    assert ts.get_column("observation").sum() == 20

    clade_counts = ts.sql(
        "select clade, sum(observation) as sum from self group by clade"
    )
    clade_counts_dict = dict(clade_counts.iter_rows())
    assert clade_counts_dict.get("other") == 9
    assert clade_counts_dict.get("AA") == 2
    assert clade_counts_dict.get("BB") == 9

    oracle = oracle.collect()
    expected_oracle_cols = set(
        ["nowcast_date", "location", "target_date", "clade", "oracle_value"]
    )
    assert set(oracle.columns) == expected_oracle_cols
    assert oracle.height == ts.height


def test_target_data_integration(caplog, tmp_path):
    """
    If the modeled-clades file doesn't have meta.created_at, tree_as_of should default to
    nowcast_date - two days.
    """
    caplog.set_level(logging.INFO)

    nowcast_date = "2024-09-11"
    runner = CliRunner()
    result = runner.invoke(
        main,
        [
            "--nowcast-date",
            nowcast_date,
            "--target-data-dir",
            tmp_path,
        ],
        color=True,
        catch_exceptions=False,
        standalone_mode=False,
    )
    assert result.exit_code == 0
    ts = pl.read_parquet(result.return_value[0])

    # sequence date should default to nowcast_date + 90 days
    assert "sequence_as_of=2024-12-10" in caplog.text
    # tasks.json for 2024-09-11 doesn't have a meta.created_at field, so tree_as_of = nowcast_date - 2 days
    assert "tree_as_of=2024-09-09" in caplog.text

    # time series target dates should be limited to dates that match collection date min/max options
    # (2024-08-11 to 2024-09-21 is 43 days, but both have 11:59:59 timestamps, so we'd expect
    # 42 days in the time series)
    target_dates = ts["target_date"].unique().to_list()
    assert len(target_dates) == 42

    modeled_clades_path = Path("auxiliary-data/modeled-clades") / f"{nowcast_date}.json"
    modeled_clades_json = json.loads(modeled_clades_path.read_text(encoding="utf-8"))
    modeled_clades = modeled_clades_json["clades"]
    ts_clades = ts["clade"].unique().to_list()
    assert len(modeled_clades) == len(ts_clades)
    assert set(ts_clades) == (set(modeled_clades))

    # check time series column data types
    ts_schema_dict = ts.schema.to_python()
    assert ts_schema_dict.get("location") is str
    assert ts_schema_dict.get("target_date") is date
    assert ts_schema_dict.get("clade") is str
    assert ts_schema_dict.get("observation") is int

    # time series rows should = total target dates * total locations * total clades
    len(target_dates) * len(state_list) * len(modeled_clades) == ts.height

    oracle = pl.read_parquet(result.return_value[1])
    assert oracle.height == ts.height

    oracle_clades = oracle["clade"].unique().to_list()
    assert len(modeled_clades) == len(oracle_clades)
    assert set(oracle_clades) == (set(modeled_clades))

    # check oracle column data types
    oracle_schema_dict = oracle.schema.to_python()
    assert oracle_schema_dict.get("nowcast_date") is str
    assert oracle_schema_dict.get("location") is str
    assert oracle_schema_dict.get("target_date") is date
    assert oracle_schema_dict.get("clade") is str
    assert oracle_schema_dict.get("oracle_value") is int
