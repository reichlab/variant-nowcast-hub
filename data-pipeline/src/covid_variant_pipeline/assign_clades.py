import subprocess

from covid_variant_pipeline.util.logs import LoggerSetup

loggy = LoggerSetup(__name__)
loggy.init_logger()
logger = loggy.logger

UPDATED_AFTER = "04/01/24"
PACKAGE_FILE = "data/ncbi_sars-cov-2.zip"


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


def get_sequence_metadata():
    """Generate tabular representation of the downloaded genbank sequences."""

    logger.info("Extracting sequence metadata...")
    fields = "accession,sourcedb,sra-accs,isolate-lineage,geo-region,geo-location,isolate-collection-date,release-date,update-date,virus-pangolin,length,host-name,isolate-lineage-source,biosample-acc,completeness,lab-host,submitter-names,submitter-affiliation,submitter-country"
    with open("data/ncbi_metadata.tsv", "w") as f:
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


def main():
    logger.info("Starting pipeline")
    get_sequences()
    get_sequence_metadata()
    get_reference_tree()


if __name__ == "__main__":
    main()
