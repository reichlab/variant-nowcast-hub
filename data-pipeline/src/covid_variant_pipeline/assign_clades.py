import datetime
import json
import os
import subprocess
from importlib import resources

import polars as pl
import rich_click as click
import structlog
from cloudpathlib import AnyPath

from covid_variant_pipeline.util.config import Config
from covid_variant_pipeline.util.reference import get_reference_data
from covid_variant_pipeline.util.sequence import get_covid_genome_data, parse_sequence_assignments

MODULE_PATH = AnyPath(resources.files("covid_variant_pipeline"))
logger = structlog.get_logger()


def setup_config(base_data_dir: str, sequence_released_date: datetime, reference_tree_as_of_date: datetime) -> Config:
    """Return an initialized Config class for the pipeline run."""

    config = Config(
        data_path_root=AnyPath(base_data_dir),
        sequence_released_date=sequence_released_date,
        reference_tree_as_of_date=reference_tree_as_of_date,
    )

    return config


def get_sequences(config: Config):
    """Download SARS-CoV-2 sequences from Genbank."""

    sequence_package = config.data_path / config.nextclade_package_name

    # API requires a datetime string for the released_since parameter
    sequence_released_date = datetime.datetime.strptime(config.sequence_released_since_date, "%Y-%m-%d")
    sequence_released_datetime = sequence_released_date.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

    get_covid_genome_data(sequence_released_datetime, filename=sequence_package)

    # unzip the data package
    subprocess.run(
        [
            "unzip",
            "-o",
            "-q",
            f"{sequence_package}",
            "-d",
            f"{config.data_path}/",
        ]
    )

    logger.info("NCBI SARS-COV-2 genome package downloaded and unzipped", package_location=sequence_package)


def get_sequence_metadata(config: Config):
    """Generate tabular representation of the downloaded genbank sequences."""

    fields = "accession,sourcedb,sra-accs,isolate-lineage,geo-region,geo-location,isolate-collection-date,release-date,update-date,virus-pangolin,length,host-name,isolate-lineage-source,biosample-acc,completeness,lab-host,submitter-names,submitter-affiliation,submitter-country"

    with open(config.ncbi_sequence_metadata_file, "w") as f:
        subprocess.run(
            [
                f"{config.executable_path}/dataformat",
                "tsv",
                "virus-genome",
                "--inputfile",
                f"{config.data_path}/ncbi_dataset/data/data_report.jsonl",
                "--fields",
                f"{fields}",
            ],
            stdout=f,
        )

    logger.info("extracted sequence metadata", metadata_file=config.ncbi_sequence_metadata_file)


def save_reference_info(config: Config) -> tuple[AnyPath, AnyPath]:
    """Download a reference tree and save it to a file."""

    reference = get_reference_data(config.nextclade_base_url, config.reference_tree_date)

    with open(config.reference_tree_file, "w") as f:
        json.dump(reference, f)

    with open(config.root_sequence_file, "w") as f:
        json.dump(reference["root_sequence"], f)

    logger.info(
        "Reference data saved",
        tree_path=str(config.reference_tree_file),
        root_sequence_path=str(config.root_sequence_file),
    )


def assign_clades(config: Config):
    """Assign downloaded genbank sequences to a clade."""

    logger.info("Assigning sequences to clades using reference tree")

    # TEMPORARY: until we fix parsing of the root sequence returned via API, use a saved root sequence
    temp_root_sequence = config.executable_path / "covid_reference_sequence.fasta"

    subprocess.run(
        [
            f"{config.executable_path}/nextclade",
            "run",
            "--input-tree",
            f"{config.reference_tree_file}",
            "--input-ref",
            f"{temp_root_sequence}",
            "--output-csv",
            f"{config.assignment_no_metadata_file}",
            f"{config.ncbi_sequence_file}",
        ]
    )


def merge_metadata(config: Config) -> pl.DataFrame:
    """Merge sequence metadata with clade assignments."""

    df_metadata = pl.read_csv(config.ncbi_sequence_metadata_file, separator="\t")

    # we're expecting one row per sequence id (aka Accession)
    # TODO: how do we want to handle the case where the metadata file has
    # duplicate Accession values?
    assert df_metadata["Accession"].n_unique() == df_metadata.shape[0]

    df_assignments = pl.read_csv(config.assignment_no_metadata_file, separator=";")
    df_assignments = parse_sequence_assignments(df_assignments)

    joined = df_metadata.join(df_assignments, left_on="Accession", right_on="seq", how="left")
    joined = joined.with_columns(
        sequence_released_since=pl.lit(config.sequence_released_since_date),
        reference_tree_date=pl.lit(config.reference_tree_date),
        sequence_retrieved_datetime=pl.lit(config.run_time),
    )
    num_sequences = joined.shape[0]

    # ?? what is the difference between "clade" and "clade_nextstrain" ??
    missing_clade_assignments = joined.filter(pl.col("clade_nextstrain").is_null())
    num_missing_assignments = missing_clade_assignments.shape[0]

    if num_missing_assignments == 0:
        logger.info("Sequence metadata merged with clade assignments", num_sequences=num_sequences)
    else:
        logger.warning(
            "Some sequences are missing clade assignments",
            num_sequences=num_sequences,
            missing_clade_assignments=missing_clade_assignments,
        )

    return joined


@click.command()
@click.option(
    "--sequence-released-since-date",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    prompt="Include SARS CoV-2 genome data released on or after this date (YYYY-MM-DD)",
    required=True,
    help="Limit the downloaded SARS CoV-2 package to sequences released on or after this date (YYYY-MM-DD format)",
)
@click.option(
    "--reference-tree-date",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    prompt="The reference tree as of date (YYYY-MM-DD)",
    required=True,
    help="Reference tree date to use for clade assignments (YYYY-MM-DD format)",
)
@click.option(
    "--data-dir",
    prompt="Directory where the clade assignment file will be saved (do not use ~)",
    default=str(MODULE_PATH / "data"),
    help=f"Directory where the clade assignment file will be saved. Default: {str(MODULE_PATH / 'data')}.",
)
def main(sequence_released_since_date: datetime.date, reference_tree_date: datetime.date, data_dir: str):
    # TODO: do we need additional date validations (e.g., no future dates)?

    config = setup_config(data_dir, sequence_released_since_date, reference_tree_date)
    logger.info("Starting pipeline", reference_tree_date=reference_tree_date, run_time=config.run_time)

    os.makedirs(config.data_path, exist_ok=True)
    get_sequences(config)
    get_sequence_metadata(config)
    save_reference_info(config)
    assign_clades(config)

    merged_data = merge_metadata(config)
    merged_data.write_csv(config.assignment_file)

    logger.info(
        "Sequence clade assignments are ready",
        assignment_file=config.assignment_file,
        run_time=config.run_time,
        reference_tree_date=config.reference_tree_date,
    )


if __name__ == "__main__":
    main()
