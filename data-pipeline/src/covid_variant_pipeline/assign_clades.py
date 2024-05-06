import json
import subprocess
from importlib import resources

import requests
import rich_click as click
import structlog
from cloudpathlib import AnyPath

from covid_variant_pipeline.util.reference import get_reference_data

logger = structlog.get_logger()

# TODO put these in a config file when we're further along
UPDATED_AFTER = "04/15/24"
MODULE_PATH = AnyPath(resources.files("covid_variant_pipeline"))
DATA_DIR = MODULE_PATH / "data"
EXECUTABLE_DIR = MODULE_PATH / "bin"
REFERENCE_DIR = DATA_DIR / "reference"
PACKAGE_NAME = "ncbi_sars-cov-2"
PACKAGE_FILE = f"{DATA_DIR}/{PACKAGE_NAME}.zip"


def get_nextclade_session() -> requests.Session():
    """Return a session for the nexclade API."""

    session = requests.Session()
    session.headers.update({"Accept": "application/vnd.nextstrain.dataset.main+json"})
    session.headers.update({"Accept-Encoding": "gzip, deflate"})

    return session


def get_sequences():
    """Download SARS-CoV-2 sequences from Genbank."""

    logger.info(f"Downloading sequences updated after {UPDATED_AFTER}...")
    subprocess.run(
        [
            f"{EXECUTABLE_DIR}/datasets",
            "download",
            "virus",
            "genome",
            "taxon",
            "SARS-CoV-2",
            "--host",
            "Homo sapiens",
            "--updated-after",
            f"{UPDATED_AFTER}",
            "--filename",
            f"{PACKAGE_FILE}",
        ]
    )

    # unzip the data package
    subprocess.run(
        [
            "unzip",
            f"{PACKAGE_FILE}",
            "-d",
            f"{DATA_DIR}/",
        ]
    )


def get_sequence_metadata():
    """Generate tabular representation of the downloaded genbank sequences."""

    logger.info("Extracting sequence metadata...")
    fields = "accession,sourcedb,sra-accs,isolate-lineage,geo-region,geo-location,isolate-collection-date,release-date,update-date,virus-pangolin,length,host-name,isolate-lineage-source,biosample-acc,completeness,lab-host,submitter-names,submitter-affiliation,submitter-country"

    with open(f"{DATA_DIR}/ncbi_metadata.tsv", "w") as f:
        subprocess.run(
            [
                f"{EXECUTABLE_DIR}/dataformat",
                "tsv",
                "virus-genome",
                "--inputfile",
                f"{DATA_DIR}/ncbi_dataset/data/data_report.jsonl",
                "--fields",
                f"{fields}",
            ],
            stdout=f,
        )


def save_reference_info(as_of_date: str) -> AnyPath:
    """Download a reference tree and save it to a file."""

    reference = get_reference_data(get_nextclade_session(), as_of_date)

    tree_file_path = REFERENCE_DIR / f"{as_of_date}_tree.json"
    with open(tree_file_path, "w") as f:
        json.dump(reference, f)

    root_sequence_file_path = REFERENCE_DIR / f"{as_of_date}_root_sequence.json"
    with open(root_sequence_file_path, "w") as f:
        json.dump(reference["root_sequence"], f)

    logger.info("Reference data saved", tree_path=str(tree_file_path), root_sequence_path=str(root_sequence_file_path))

    return tree_file_path, root_sequence_file_path


def assign_clades(as_of_date: str, reference_tree: AnyPath, root_sequence: AnyPath):
    """Assign downloaded genbank sequences to a clade."""

    logger.info(f"Assigning sequences to clades using reference tree {reference_tree}")
    sequence_file = f"{DATA_DIR}/ncbi_dataset/data/genomic.fna"
    assignment_file = f"{DATA_DIR}/{as_of_date}_clade_assignments.csv"

    subprocess.run(
        [
            f"{EXECUTABLE_DIR}/nextclade",
            "run",
            "--input-tree",
            f"{reference_tree}",
            "--input-ref",
            f"{DATA_DIR}/covid_reference_sequence.fasta",
            "--output-csv",
            f"{assignment_file}",
            f"{sequence_file}",
        ]
    )

    return assignment_file


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
    logger.info("Starting pipeline", as_of_date=as_of_date)

    get_sequences()
    get_sequence_metadata()
    reference_tree_path, root_sequence_path = save_reference_info(as_of_date)
    assignment_file = assign_clades(as_of_date, reference_tree_path, root_sequence_path)

    logger.info("Sequence clade assignments are ready", assignment_file=assignment_file)


if __name__ == "__main__":
    main()
