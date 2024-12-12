"""
Sample script for using Cladetime's assign_clades feature

To run the script manually:
1. Install uv on your machine: https://docs.astral.sh/uv/getting-started/installation/
2. From the root of this repo: uv run src/sample_get_target_data.py

IMPORTANT NOTE! If you want to try the script on a subset of Nextstrain data
(rather than a full dataset of sequences), set an environment variable named
CLADETIME_DEMO to true before running the scripts.
For example, on MacOS:
export CLADETIME_DEMO=true

DO NOT SET CLADETIME_DEMO TO TRUE IF YOU WANT TO USE THE FULL DATASET OF SEQUENCES
(for example when generating target data)
"""

# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "cladetime@git+https://github.com/reichlab/cladetime",
# ]
# ///

from datetime import datetime, timezone

from cladetime import CladeTime, sequence


def main():
    # instantiate CladeTime object
    #   - sequence_as_of = use SARS-CoV-2 sequences as they existing on this date
    #   - tree_as_of = for clade assignment, use the reference tree as it existed on this date
    ct = CladeTime(sequence_as_of=datetime.now(timezone.utc), tree_as_of="2024-09-11")

    # filter metadata down to the sequences you want to assign clades to
    filtered_metadata = sequence.filter_metadata(
        ct.sequence_metadata,
        collection_min_date="2024-11-01",
        collection_max_date="2024-11-30",
    )

    # assign clades
    assigned_clades = ct.assign_clades(filtered_metadata)

    # save summarized clades to a file
    assigned_clades.summary.collect().write_csv("summarized_clades.csv")
    # or output to another data structure
    # (optional: if you're using polars in python or if you're using R, you can skip this)
    assigned_clades.summary.collect().to_pandas()

    # the detailed file is larger, so if you need to save it, parquet is a good option
    assigned_clades.detail.collect().write_parquet("detailed_clades.parquet")


if __name__ == "__main__":
    main()
