import subprocess

from covid_variant_pipeline.util.logs import LoggerSetup

loggy = LoggerSetup(__name__)
loggy.init_logger()
logger = loggy.logger


def get_sequences():
    """Download SARS-CoV-2 sequences from Genbank."""

    updated_after = "04/01/24"
    package_file = "data/ncbi_sars-cov-2.zip"

    logger.info(f"Downloading sequences updated after {updated_after}...")
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
            f"{updated_after}",
            "--filename",
            f"{package_file}",
        ]
    )


def main():
    logger.info("Starting pipeline")
    get_sequences()


if __name__ == "__main__":
    main()
