# Target Data

The United States SARS-CoV-2 Variant Nowcast Hub generates target data in both oracle output and time series formats
as described in the [Hubverse user guide](https://hubverse.io/en/latest/user-guide/target-data.html).

> [!TIP]
> The GitHub workflow described below can be manually re-run if needed.

## Target data process

Target data files are generated weekly via the
[`run-post-submission-jobs.yaml`](https://github.com/reichlab/variant-nowcast-hub/blob/main/.github/workflows/run-post-submission-jobs.yaml)
GitHub workflow, which runs after submissions close for a round (early Thursday mornings UTC).

The workflow has a single input parameter: `nowcast-date`. This YYYY-MM-DD date string represents a modeling
round_id and defaults to the most recent Wednesday when not explicitly set.

Using `nowcast-date` as a baseline, `run-post-submission-jobs.yaml` generates fourteen sets of oracle output and
time series target data files:

- (`nowcast_date` - 13 weeks): generates target data for the round that
  is officially "closed" by the workflow run

    - `nowcast_date` - 13 weeks (or 91 days) is also known as `round_close_date`
    - target data from this run is used for scoring models

- (`nowcast_date` - 12 weeks) through (`nowcast_date` - 0 weeks)

    - `nowcast_date` - 0 weeks = the workflow's input parameter and is also
      referred to as `submission_close_date`
    - generates interim target data used to track model performance and
      potentially for visualizations

### Dates

For each of the fourteen modeling rounds listed above, `run-post-submission-jobs.yaml` executes
[`src/get_target_data.py`](https://github.com/reichlab/variant-nowcast-hub/blob/main/src/get_target_data.py).

The table below defines all `get_target_data.py` parameters. All dates are represented by strings in YYYY-MM-DD format.

| date name | definition/used for | how it's calculated |
|------------|-----------|------------------------------------|
| `nowcast_date` | a modeling round id | passed by workflow: one of the 14 modeleing rounds being processed by the `run-post-submissions-jobs.yaml` workflow |
| `sequence_as_of` | date used to retrieve Nexstrain SARS-CoV-2 sequences; `as_of` partition key value for time series output | passed by workflow: `round_close_date` + 90 days (a Tuesday). |
| `target-data-dir` | where to save the target data files | passed by workflow: repo's `target-data` directory |
| `tree_as_of` | The SARS-CoV-2 reference tree in use when the `nowcast_date` modeling round opened; used to assign clades to above sequences | `meta.created_at` value in the round's [modeled-clades](https://github.com/reichlab/variant-nowcast-hub/tree/main/auxiliary-data/modeled-clades) .json file (usually `nowcast_date` - 2 days) |
| `collection_min_date` | use SARS-CoV-2 sequences collected on or after this date when generating time series target data | `tree_as_of` - 90 days |
| `collection_max_date` | use SARS-CoV-2 sequences collected on or before this date when generating target data | `nowcast_date` + 10 days |

### Values

At a high level, `get_target_data.py` calculates target data values by:

1. Downloading the set of SARS-CoV-2 genome sequences that were available on the `as_of` date.
2. Assigning clades to those sequences using the SARS-CoV-2 reference tree in effect on the `tree_as_of` date.
3. Summarizing the number of sequences by location, target date, and clade.

## Oracle output

The hub's oracle output target data are published in parquet format and partitioned by `nowcast_date`.

Oracle output files are used to evaluate model submissions and contain the following columns:

| Name | Data Type | Description |
|------------|-----------|------------------------------------|
| nowcast_date | date | modeling round identifier |
| location | string | two-letter U.S. state abbreviation that corresponds to oracle_value |
| target_date | date | sequence collection date that corresponds to oracle_value |
| clade | string | [Nextstrain clade](https://nextstrain.org/blog/2021-01-06-updated-SARS-CoV-2-clade-naming) that corresponds to oracle_value |
| oracle_value | integer | the observed total of sequences for a location, target_date, and Nextstrain clade |
| as_of | date | date that SARS-CoV-2 sequence data was accessed when computing the oracle_value |

## Time series output

The hub's time series target data are published in parquet format and partitioned by:

- `as_of`
- `nowcast_date`

Time series values are calculated by using SARS-CoV-2 sequence data and clade assignments as they existed on
the `as_of` date.

Time series files are used for model estimation and plotting and contain the following columns:

| Name | Data Type | Description |
|------------|-----------|------------------------------------|
| as_of | date | date that SARS-CoV-2 sequence data was accessed when computing observed values |
| nowcast_date | date | modeling round identifier |
| location | string | two-letter U.S. state abbreviation that corresponds to the observation |
| target_date | date | sequence collection date that corresponds to the observation |
| clade | string | [Nextstrain clade](https://nextstrain.org/blog/2021-01-06-updated-SARS-CoV-2-clade-naming) that corresponds to the observation |
| observation | integer | the observed total of sequences for a location, target_date, and Nextstrain clade |

## Data Anomolies and Changes
Occasionally, there are changes or anomalies in the data collection process; this section contains a record of these events for future use.
### Data Changes
The data collection process was updated the week of April 16, 2025 to retain more sequences. This means that data after than week will be different from the data before that week. [This thread](https://github.com/reichlab/cladetime/issues/113) has more details on the exact changes made.
### Data Anomolies
On the week of May 14, 2025, there was a bug upstream in the data collection process that resulted in less data being available than usual; see [this thread](https://github.com/nextstrain/ncov-ingest/pull/501) for more details.
## Acknowledgments

The United States SARS-CoV-2 Variant Nowcast Hub uses Genbank-based genome sequences
published by Nextstrain:

- [Hadfield et al., Nextstrain: real-time tracking of pathogen evolution, Bioinformatics (2018)](https://academic.oup.com/bioinformatics/article/34/23/4121/5001388?login=false)
- [https://nextstrain.org/](https://nextstrain.org/)

Additionally, the hub uses the
[Nextclade project](https://docs.nextstrain.org/projects/nextclade/en/stable/)
to assign clades to SARS-CoV-2 genome sequences.

- Aksamentov, I., Roemer, C., Hodcroft, E. B., & Neher, R. A., (2021).
  Nextclade: clade assignment, mutation calling and quality control for viral genomes.
  Journal of Open Source Software, 6(67), 3773, [https://doi.org/10.21105/joss.03773](https://doi.org/10.21105/joss.03773)
- [https://clades.nextstrain.org](https://clades.nextstrain.org)
