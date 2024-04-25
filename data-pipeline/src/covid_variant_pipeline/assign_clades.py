import subprocess

from covid_variant_pipeline.util.logs import LoggerSetup

loggy = LoggerSetup(__name__)
loggy.init_logger()
logger = loggy.logger

UPDATED_AFTER = "04/01/24"
DATA_DIR = "data"
PACKAGE_NAME = "ncbi_sars-cov-2"
PACKAGE_FILE = f"{DATA_DIR}/{PACKAGE_NAME}.zip"


def get_sequences():
    """Download SARS-CoV-2 sequences from Genbank."""

    logger.info(f"Downloading sequences updated after {UPDATED_AFTER}...")
    subprocess.run(
        [
            "bin/datasets",
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
                "bin/dataformat",
                "tsv",
                "virus-genome",
                "--package",
                f"{PACKAGE_FILE}",
                "--fields",
                f"{fields}",
            ],
            stdout=f,
        )


def get_reference_tree():
    """Download a reference tree as of a specific date."""
    logger.info("Reference tree download not yet implemented, using static copy: data/reference.json")


def assign_clades():
    """Assign downloaded genbank sequences to a clade."""

    logger.info("Assigning sequences to clades...")
    sequence_file = f"{DATA_DIR}/ncbi_dataset/data/genomic.fna"
    assignment_file = f"{DATA_DIR}/clade_assignments.csv"

    with open(f"{DATA_DIR}/clade_assignments.csv", "w") as f:
        subprocess.run(
            [
                "bin/nextclade",
                "run",
                "--input-tree",
                f"{DATA_DIR}/reference.json",
                "--input-ref",
                f"{DATA_DIR}/covid_reference_sequence.fasta",
                "--output-csv",
                f"{assignment_file}",
                f"{sequence_file}",
            ],
            stdout=f,
        )

    return assignment_file


def main():
    logger.info("Starting pipeline")
    get_sequences()
    get_sequence_metadata()
    get_reference_tree()
    assignment_file = assign_clades()

    logger.info(f"Sequence clade assignments are ready at {assignment_file}")


if __name__ == "__main__":
    main()
