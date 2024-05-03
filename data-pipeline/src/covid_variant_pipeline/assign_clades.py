import subprocess
from importlib import resources

from covid_variant_pipeline.util.logs import LoggerSetup

loggy = LoggerSetup(__name__)
loggy.init_logger()
logger = loggy.logger

UPDATED_AFTER = "04/15/24"

# get a path object to module's location
MODULE_PATH = resources.files("covid_variant_pipeline")
DATA_DIR = MODULE_PATH / "data"
EXECUTABLE_DIR = MODULE_PATH / "bin"
PACKAGE_NAME = "ncbi_sars-cov-2"
PACKAGE_FILE = f"{DATA_DIR}/{PACKAGE_NAME}.zip"

# randomly chose a reference tree with a last modified date of 2024-01-19
# to get a list of available versions using the AWS CLI:
# aws s3api list-object-versions --bucket nextstrain-data --prefix files/ncov/open/reference/reference.json --no-sign-request
REFERENCE_TREE_VERSION = "lXbwzM1oPzrvX.2RliJ245pvkjEZCIFA"


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


def get_reference_tree():
    """Download a reference tree."""

    reference_tree_file = f"{DATA_DIR}/reference_tree-{REFERENCE_TREE_VERSION}.json"
    logger.info(f"downloading reference tree to {reference_tree_file}")

    subprocess.run(
        [
            "aws",
            "s3api",
            "get-object",
            "--bucket",
            "nextstrain-data",
            "--key",
            "files/ncov/open/reference/reference.json",
            f"{reference_tree_file}",
            "--version-id",
            f"{REFERENCE_TREE_VERSION}",
            "--no-sign-request",
        ]
    )

    return reference_tree_file


def assign_clades(reference_tree: str):
    """Assign downloaded genbank sequences to a clade."""

    logger.info(f"Assigning sequences to clades using reference tree {reference_tree}")
    sequence_file = f"{DATA_DIR}/ncbi_dataset/data/genomic.fna"
    assignment_file = f"{DATA_DIR}/clade_assignments-{REFERENCE_TREE_VERSION}.csv"

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


def main():
    logger.info("Starting pipeline")
    get_sequences()
    get_sequence_metadata()
    reference_tree_file = get_reference_tree()
    assignment_file = assign_clades(reference_tree_file)

    logger.info(f"Sequence clade assignments are ready at {assignment_file}")


if __name__ == "__main__":
    main()
