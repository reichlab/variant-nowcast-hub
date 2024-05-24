import datetime
import json
import os
import subprocess
from importlib import resources

import polars as pl
import rich_click as click
import structlog
from cloudpathlib import AnyPath

from covid_variant_pipeline.util.reference import get_reference_data
from covid_variant_pipeline.util.sequence import get_covid_genome_data, parse_sequence_assignments

logger = structlog.get_logger()

# TODO put these in a config file when we're further along
UPDATED_AFTER = "05/01/24"
MODULE_PATH = AnyPath(resources.files("covid_variant_pipeline"))
DATA_DIR = MODULE_PATH / "data"
EXECUTABLE_DIR = MODULE_PATH / "bin"
SEQUENCE_DIR = DATA_DIR / "sequence"
SEQUENCE_FILE = "ncbi_dataset/data/genomic.fna"
REFERENCE_DIR = DATA_DIR / "reference"
ASSIGNMENT_DIR = DATA_DIR / "assignment"
NEXTCLADE_BASE_URL = "https://nextstrain.org/nextclade/sars-cov-2"
PACKAGE_NAME = "ncbi.zip"


def get_sequences(run_time: str) -> AnyPath:
    """Download SARS-CoV-2 sequences from Genbank."""

    sequence_dir = SEQUENCE_DIR / run_time
    sequence_package = sequence_dir / PACKAGE_NAME

    os.makedirs(sequence_dir, exist_ok=True)

    # TODO: maybe add released_since_date to the CLI options?
    # Currently, function below will use a default of 2 weeks ago
    get_covid_genome_data(filename=sequence_package)

    # unzip the data package
    subprocess.run(
        [
            "unzip",
            "-q",
            f"{sequence_package}",
            "-d",
            f"{sequence_dir}/",
        ]
    )

    logger.info(
        "NCBI SARS-COV-2 genome package downloaded and unzipped", run_time=run_time, package_location=sequence_package
    )
    return sequence_dir


def get_sequence_metadata(run_time: str, sequence_dir: str):
    """Generate tabular representation of the downloaded genbank sequences."""

    fields = "accession,sourcedb,sra-accs,isolate-lineage,geo-region,geo-location,isolate-collection-date,release-date,update-date,virus-pangolin,length,host-name,isolate-lineage-source,biosample-acc,completeness,lab-host,submitter-names,submitter-affiliation,submitter-country"
    metadata_file = f"{sequence_dir}/{run_time}-metadata.tsv"

    with open(metadata_file, "w") as f:
        subprocess.run(
            [
                f"{EXECUTABLE_DIR}/dataformat",
                "tsv",
                "virus-genome",
                "--inputfile",
                f"{sequence_dir}/ncbi_dataset/data/data_report.jsonl",
                "--fields",
                f"{fields}",
            ],
            stdout=f,
        )

    logger.info("extracted sequence metadata", run_time=run_time, metadata_file=metadata_file)
    return metadata_file


def save_reference_info(as_of_date: str) -> tuple[AnyPath, AnyPath]:
    """Download a reference tree and save it to a file."""

    reference = get_reference_data(NEXTCLADE_BASE_URL, as_of_date)

    tree_file_path = REFERENCE_DIR / f"{as_of_date}_tree.json"
    with open(tree_file_path, "w") as f:
        json.dump(reference, f)

    root_sequence_file_path = REFERENCE_DIR / f"{as_of_date}_root_sequence.json"
    with open(root_sequence_file_path, "w") as f:
        json.dump(reference["root_sequence"], f)

    logger.info("Reference data saved", tree_path=str(tree_file_path), root_sequence_path=str(root_sequence_file_path))

    return tree_file_path, root_sequence_file_path


def assign_clades(run_time: str, sequence_dir: AnyPath, reference_tree: AnyPath, root_sequence: AnyPath):
    """Assign downloaded genbank sequences to a clade."""

    logger.info(f"Assigning sequences to clades using reference tree {reference_tree}")
    sequence_file = sequence_dir / SEQUENCE_FILE
    assignment_file = f"{ASSIGNMENT_DIR}/{run_time}_clade_assignments_no_metadata.csv"

    # temporary: until we fix parsing of the root sequence returned via API, we'll hard-code
    # the once we saved earlier
    root_sequence = REFERENCE_DIR / "covid_reference_sequence.fasta"

    subprocess.run(
        [
            f"{EXECUTABLE_DIR}/nextclade",
            "run",
            "--input-tree",
            f"{reference_tree}",
            "--input-ref",
            f"{root_sequence}",
            "--output-csv",
            f"{assignment_file}",
            f"{sequence_file}",
        ]
    )

    return assignment_file


def merge_metadata(
    as_of_date: str, run_datetime: datetime.datetime, metadata_file: AnyPath, assignment_file: AnyPath
) -> pl.DataFrame:
    """Merge sequence metadata with clade assignments."""

    df_metadata = pl.read_csv(metadata_file, separator="\t")

    # we're expecting one row per sequence id (aka Accession)
    # TODO: how do we want to handle the case where the metadata file has
    # duplicate Accession values?
    assert df_metadata["Accession"].n_unique() == df_metadata.shape[0]

    df_assignments = pl.read_csv(assignment_file, separator=";")
    df_assignments = parse_sequence_assignments(df_assignments)

    joined = df_metadata.join(df_assignments, left_on="Accession", right_on="seq", how="left")
    joined = joined.with_columns(
        sequence_retrieved_datetime=run_datetime,
        reference_tree_date=datetime.datetime.strptime(as_of_date, "%Y-%m-%d").date(),
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
    "--as-of-date",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    prompt="Reference tree as of (YYYY-MM-DD)",
    required=True,
    help="Reference tree date to use for clade assignments (YYYY-MM-DD format)",
)
def main(as_of_date: str):
    # TODO: do we need additional date validations?

    # incoming as_of_date comes in as a datetime object (for validation purposes), convert back to string now
    as_of_date = as_of_date.strftime("%Y-%m-%d")
    now = datetime.datetime.now()
    run_time = now.strftime("%Y%m%dT%H%M%S")

    logger.info("Starting pipeline", as_of_date=as_of_date, run_time=run_time)

    sequence_dir = get_sequences(run_time)
    metadata_file = get_sequence_metadata(run_time, sequence_dir)
    reference_tree_path, root_sequence_path = save_reference_info(as_of_date)
    assignment_file = assign_clades(run_time, sequence_dir, reference_tree_path, root_sequence_path)

    merged_data = merge_metadata(as_of_date, now, metadata_file, assignment_file)
    final_assignment_file = f"{ASSIGNMENT_DIR}/{run_time}_clade_assignments.csv"
    merged_data.write_csv(final_assignment_file)

    logger.info(
        "Sequence clade assignments are ready",
        assignment_file=final_assignment_file,
        run_time=run_time,
        as_of_date=as_of_date,
    )


if __name__ == "__main__":
    main()
