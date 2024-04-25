from covid_variant_pipeline.util.logs import LoggerSetup

loggy = LoggerSetup(__name__)
loggy.init_logger()
logger = loggy.logger


def main():
    logger.info("Starting pipeline")


if __name__ == "__main__":
    main()
