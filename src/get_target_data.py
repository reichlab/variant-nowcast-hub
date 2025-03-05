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
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "click",
#   "cladetime@git+https://github.com/reichlab/cladetime",
#   "polars>=1.17.1,<1.18.0",
#   "pyarrow>=18.1.0,<19.0.0",
# ]
# ///

import json
from pathlib import Path
import logging
import sys
from datetime import date, datetime, timedelta, timezone

import click
import polars as pl
import pyarrow as pa  # type: ignore
import pyarrow.dataset as ds  # type: ignore
import pyarrow.parquet as pq  # type: ignore
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


def set_collection_max_date(ctx, param, value):
    """Set the collection_max_date default value to nowcast date plus 10 days."""
    if value is None:
        nowcast_date = ctx.params.get("nowcast_date")
        value = nowcast_date + timedelta(days=10)
    value = value.replace(hour=23, minute=59, second=59, tzinfo=timezone.utc)
    return value


def set_target_data_dir(ctx, param, value):
    """Set the target_data_dir default value to the hub's target-data directory."""
    if value is None:
        value = Path(__file__).parents[1] / "target-data"
    elif value == ".":
        value = Path.cwd()
    else:
        value = Path(value)

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
    callback=normalize_date,
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
    type=str,
    required=False,
    default=None,
    callback=set_target_data_dir,
    help=(
        "Path object to the directory where the target data will be saved. Default is the hub's target-data directory. "
        "Specify '.' to save target data to the current working directory."
    ),
)
def main(
    nowcast_date: datetime,
    sequence_as_of: datetime,
    tree_as_of: datetime,
    collection_min_date: datetime,
    collection_max_date: datetime,
    target_data_dir: Path,
) -> tuple[Path, Path]:
    # Date for retrieving sequences cannot be in the future
    if sequence_as_of > datetime.now(tz=timezone.utc):
        logger.info(
            f"Stopping script. Sequence_as_of is in the future: {sequence_as_of}"
        )
        sys.exit(1)

    # Nowcast_date must match a variant-nowcast-hub round_id
    nowcast_string = nowcast_date.strftime("%Y-%m-%d")
    modeled_clades_path = (
        Path(__file__).parents[1]
        / "auxiliary-data"
        / "modeled-clades"
        / f"{nowcast_string}.json"
    )
    if not modeled_clades_path.is_file():
        logger.info(
            f"Stopping script. No round found for nowcast_date: {nowcast_string}"
        )
        sys.exit(0)
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

    if collection_min_date is None:
        collection_min_date = tree_as_of - timedelta(days=90)

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
        .with_columns(
            pl.lit(nowcast_string).alias("nowcast_date"),
            pl.lit(sequence_as_of_string).alias("as_of"),
        )
        .rename(
            {
                "count": "observation",
                "date": "target_date",
            }
        )
    )

    oracle_output = (
        time_series_all.select(["location", "target_date", "clade", "observation"])
        # for oracle output, include only sequence collection dates that are >=
        # nowcast_date - 31 days
        .filter(
            pl.col("target_date")
            >= datetime.fromisoformat(nowcast_string) - timedelta(days=31)
        )
        .with_columns(
            pl.lit(nowcast_string).alias("nowcast_date"),
            pl.lit(sequence_as_of_string).alias("as_of"),
        )
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
    """
    Write time series and oracle output target data.

    This function converts the target data LazyFrames to arrow tables
    and explicitly specifies what the schema should be. This ensures that the
    R Hubverse tools (which use arrow::read_dataset to read parquet files) will
    not get a data type mismatch between the values in folder names used for
    Hive-style partitioning the corresponding columns in the parquet files.
    https://github.com/reichlab/variant-nowcast-hub/issues/265
    """

    # write time series data
    target_time_series_dir = target_data_dir / "time-series"

    ts_output_path = (
        target_time_series_dir
        / f"as_of={sequence_as_of_string}/nowcast_date={nowcast_string}"
    )
    ts_output_path.mkdir(exist_ok=True, parents=True)
    ts_output_path = ts_output_path / "timeseries.parquet"

    time_series = target_data[0]
    time_series_arrow = time_series.collect().to_arrow()

    ts_schema = pa.schema(
        [
            ("target_date", pa.date32()),
            ("location", pa.string()),
            ("clade", pa.string()),
            ("observation", pa.int64()),
            ("nowcast_date", pa.date32()),
            ("as_of", pa.date32()),
        ]
    )
    time_series_arrow = time_series_arrow.cast(ts_schema)
    pq.write_table(time_series_arrow, ts_output_path, use_dictionary=False)
    logger.info(f"Target time series saved to {ts_output_path}")

    # write oracle output data
    target_oracle_output_dir = target_data_dir / "oracle-output"
    oracle_output_path = target_oracle_output_dir / f"nowcast_date={nowcast_string}"
    oracle_output_path.mkdir(exist_ok=True, parents=True)
    oracle_output_path = oracle_output_path / "oracle.parquet"

    oracle = target_data[1]
    oracle_arrow = oracle.collect().to_arrow()

    oracle_schema = pa.schema(
        [
            ("location", pa.string()),
            ("target_date", pa.date32()),
            ("clade", pa.string()),
            ("oracle_value", pa.int64()),
            ("nowcast_date", pa.date32()),
            ("as_of", pa.date32()),
        ]
    )
    oracle_arrow = oracle_arrow.cast(oracle_schema)
    pq.write_table(oracle_arrow, oracle_output_path, use_dictionary=False)
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

    # if collection_min_date is provided, it should be set to end of day UTC
    param = Option(["--collection-min-date"])
    result = normalize_date(ctx, param, datetime(2024, 11, 11, 11, 11, 11))
    assert result == datetime(2024, 11, 11, 23, 59, 59, tzinfo=timezone.utc)

    # default collection_max_date is 10 days after the nowcast date
    param = Option(["--collection-max-date"])
    result = set_collection_max_date(ctx, param, None)
    assert result == datetime(2024, 10, 12, 23, 59, 59, tzinfo=timezone.utc)


def test_bad_inputs(caplog):
    """Bad inputs should return a non-zero exit code or a graceful script exit."""
    caplog.set_level(logging.INFO)
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
        assert result.exit_code == 0
        assert "stopping script" in caplog.text.lower()


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
    test_assignments = Clade(
        {"tree_as_of": datetime(2024, 8, 1, 14, 30, 40)},
        pl.LazyFrame(),
        pl.LazyFrame(test_summary),
    )
    test_clade_list = ["AA", "BB", "other"]
    test_min_date = datetime(2024, 11, 30, tzinfo=timezone.utc)
    test_max_date = datetime(2024, 12, 4, tzinfo=timezone.utc)
    time_series, oracle = create_target_data(
        test_assignments,
        test_clade_list,
        "2024-09-11",
        "2024-12-17",
        test_min_date,
        test_max_date,
    )
    ts = time_series.collect()

    # time series row count should = 5 days * 3 clades * 52 locations
    assert ts.height == 5 * 3 * 52

    expected_time_series_cols = set(
        [
            "location",
            "target_date",
            "clade",
            "observation",
            "nowcast_date",
            "as_of",
        ]
    )
    assert set(ts.columns) == expected_time_series_cols

    assert set(ts.get_column("clade").to_list()) == {"AA", "BB", "other"}
    assert ts.get_column("target_date").min() == date(2024, 11, 30)
    assert ts.get_column("target_date").max() == date(2024, 12, 4)
    assert ts.get_column("observation").sum() == 20
    assert ts.get_column("nowcast_date").unique().to_list() == ["2024-09-11"]
    assert ts.get_column("as_of").unique().to_list() == ["2024-12-17"]

    clade_counts = ts.sql(
        "select clade, sum(observation) as sum from self group by clade"
    )
    clade_counts_dict = dict(clade_counts.iter_rows())
    assert clade_counts_dict.get("other") == 9
    assert clade_counts_dict.get("AA") == 2
    assert clade_counts_dict.get("BB") == 9

    oracle = oracle.collect()
    expected_oracle_cols = set(
        ["nowcast_date", "location", "target_date", "clade", "oracle_value", "as_of"]
    )
    assert set(oracle.columns) == expected_oracle_cols
    assert oracle.height == ts.height


def test_target_data_integration(caplog, tmp_path):
    """
    If the modeled-clades file doesn't have meta.created_at, tree_as_of should default to
    nowcast_date - two days. Additionally, when collection_min_date isn't provided,
    it should default to tree_as_of - 90 days.
    """
    caplog.set_level(logging.INFO)

    nowcast_date = "2024-09-11"
    runner = CliRunner(env={"CLADETIME_DEMO": "true"})
    result = runner.invoke(
        main,
        [
            "--nowcast-date",
            nowcast_date,
            "--target-data-dir",
            str(tmp_path),
        ],
        color=True,
        catch_exceptions=False,
        standalone_mode=False,
    )
    assert result.exit_code == 0

    ts_path = result.return_value[0]
    oracle_path = result.return_value[1]
    ts = pl.read_parquet(ts_path)

    # sequence date should default to nowcast_date + 90 days
    assert "sequence_as_of=2024-12-10" in caplog.text.lower()
    # tasks.json for 2024-09-11 doesn't have a meta.created_at field, so tree_as_of = nowcast_date - 2 days
    assert "tree_as_of=2024-09-09" in caplog.text.lower()

    # number of unique dates in the time series target should be the number of
    # days between collection_min_date (tree_as_of - 90 days) and the
    # collection_max_date (nowcast_date + 10 days), inclusive
    nowcast_datetime = datetime.fromisoformat(nowcast_date).replace(
        hour=11, minute=59, second=59, tzinfo=timezone.utc
    )
    tree_as_of_datetime = datetime.fromisoformat("2024-09-09").replace(
        hour=11, minute=59, second=59, tzinfo=timezone.utc
    )
    expected_num_days = (
        (nowcast_datetime + timedelta(days=10))
        - (tree_as_of_datetime - timedelta(days=90))
    ).days + 1
    target_dates = ts["target_date"].unique().to_list()
    assert len(target_dates) == expected_num_days

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
    assert ts_schema_dict.get("nowcast_date") is date
    assert ts_schema_dict.get("as_of") is date

    # time series rows should = total target dates * total locations * total clades
    len(target_dates) * len(state_list) * len(modeled_clades) == ts.height

    oracle = pl.read_parquet(oracle_path)

    oracle_min_date = oracle["target_date"].min()
    oracle_max_date = oracle["target_date"].max()
    assert (
        oracle_min_date
        == (datetime.strptime(nowcast_date, "%Y-%m-%d") - timedelta(days=31)).date()
    )
    assert (
        oracle_max_date
        == (datetime.strptime(nowcast_date, "%Y-%m-%d") + timedelta(days=10)).date()
    )

    # oracle series rows should = number of oracle target dates * total locations * total clades
    expected_num_days = (oracle_max_date - oracle_min_date).days + 1
    assert oracle.height == expected_num_days * len(state_list) * len(modeled_clades)

    oracle_clades = oracle["clade"].unique().to_list()
    assert len(modeled_clades) == len(oracle_clades)
    assert set(oracle_clades) == (set(modeled_clades))

    # check oracle column data types on Polars dataframe
    oracle_schema_dict = oracle.schema.to_python()
    assert oracle_schema_dict.get("nowcast_date") is date
    assert oracle_schema_dict.get("location") is str
    assert oracle_schema_dict.get("target_date") is date
    assert oracle_schema_dict.get("clade") is str
    assert oracle_schema_dict.get("oracle_value") is int
    assert oracle_schema_dict.get("as_of") is date

    # check data types when reading target data with Arrow
    ts_arrow = ds.dataset(str(ts_path), format="parquet")
    ts_schema = ts_arrow.schema
    assert ts_schema.field("nowcast_date").type == pa.date32()
    assert ts_schema.field("location").type == pa.string()
    assert ts_schema.field("clade").type == pa.string()
    assert ts_schema.field("observation").type == pa.int64()
    assert ts_schema.field("target_date").type == pa.date32()
    assert ts_schema.field("as_of").type == pa.date32()

    oracle_arrow = ds.dataset(str(oracle_path), format="parquet")
    oracle_schema = oracle_arrow.schema
    assert oracle_schema.field("nowcast_date").type == pa.date32()
    assert oracle_schema.field("location").type == pa.string()
    assert oracle_schema.field("clade").type == pa.string()
    assert oracle_schema.field("oracle_value").type == pa.int64()
    assert oracle_schema.field("target_date").type == pa.date32()
    assert oracle_schema.field("as_of").type == pa.date32()
