"""
Create a parquet file with clade counts by date and location and save it to an S3 bucket.

This script wraps the cladetime package, which generates the clade counts using the
GenBank-based Sars-CoV-2 sequence metadata from Nextstrain.
https://github.com/reichlab/cladetime

The script is scheduled to run every Monday, for use in the modeling round that will open
on the following Wednesday.

To run the script manually:
1. Install uv on your machine: https://docs.astral.sh/uv/getting-started/installation/
2. From the root of this repo:
uv run src/get_location_date_counts_eval.py --reference-date=YYYY-MM-DD --sequence-as-of=YYYY-MM-DD
For example:
uv run src/get_location_date_counts_eval.py --reference-date=2024-04-24 --sequence-as-of=2024-07-13
"""

# /// script
# requires-python = "==3.12"
# dependencies = [
#   "click",
#   "cladetime@git+https://github.com/reichlab/cladetime"
# ]
# ///

import click
from pathlib import Path
import logging
from datetime import datetime, timedelta, timezone

from cladetime import CladeTime, sequence  # type: ignore

# Log to stdout
logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s -  %(levelname)s - %(message)s", datefmt="%m/%d/%Y %I:%M:%S %p"
)
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# set up data directory
data_dir = Path("./eval_data")
data_dir.mkdir(exist_ok=True)

@click.command()
@click.option(
    "--reference-date",
    type=str,
    required=True,
    help="The modeling round reference date (YYYY-MM-DD).  The tree as of date is set to this reference date minus two days.",
)
@click.option(
    "--sequence-as-of",
    type=str,
    required=False,
    help="Get counts based on the last available Nextstrain sequence metadata on or prior to this date (YYYY-MM-DD).",
)
def main(reference_date: str | None = None, sequence_as_of: str | None = None,
         windowed_sequences: bool = True):
    """Get clade counts and save to S3 bucket."""
    utc_now = datetime.now(tz=timezone.utc)
    if sequence_as_of is None or sequence_as_of == str(utc_now.date()):
        # as_of not provided or is today
        sequence_as_of_datetime = utc_now
        sequence_as_of = str(utc_now.date())
    elif sequence_as_of > str(utc_now.date()):
        raise ValueError('sequence_as_of is in the future!')
    else:
        # as_of is not today
        sequence_as_of_datetime = datetime.strptime(sequence_as_of, "%Y-%m-%d") \
            + timedelta(hours = 23, minutes = 59, seconds = 59)

    reference_date = datetime.strptime(reference_date, "%Y-%m-%d")
    tree_as_of_datetime = reference_date \
        + timedelta(-2) \
        + timedelta(hours = 23, minutes = 59, seconds = 59)
    
    collection_min_date = reference_date + timedelta(-42)
    collection_max_date = reference_date + timedelta(10)
    
    # Instantiate CladeTime object
    ct = CladeTime(sequence_as_of=sequence_as_of_datetime,
                   tree_as_of=tree_as_of_datetime)
    logger.info({
        "msg": f"CladeTime object created with sequence_as_of date = {ct.sequence_as_of} and tree_as_of date = {ct.tree_as_of}",
        "nextstrain_metadata_url": ct.url_sequence_metadata,
    })

    logger.info("filter_metadata")
    filtered_metadata = sequence.filter_metadata(
        ct.sequence_metadata,
        collection_min_date=collection_min_date,
        collection_max_date=collection_max_date
    )
    
    logger.info("assign clades")
    assignments = ct.assign_clades(filtered_metadata)
    
    logger.info("get clade counts")
    counts = assignments.summary.collect()
    
    output_file = data_dir / f"{str(reference_date)}_covid_clade_counts.parquet"
    counts.write_parquet(output_file)

    logger.info(f"Clade outputs saved: {output_file}")



if __name__ == "__main__":
    main()