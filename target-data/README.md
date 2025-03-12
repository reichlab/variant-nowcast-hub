# Target Data

The United States SARS-CoV-2 Variant Nowcast Hub generates target data in both oracle output and time series formats
as described in the [Hubverse user guide](https://hubverse.io/en/latest/user-guide/target-data.html).

## Target data process

Target data files are generated weekly, after a variant-nowcast-hub closes for submissions.
If necessary, a set of target data files can also be generated
manually.

- GitHub workflow: [`run-post-submission-jobs.yaml`](https://github.com/reichlab/variant-nowcast-hub/blob/main/.github/workflows/run-post-submission-jobs.yaml#L60)
- Python script run by above workflow: [`get_target_data.py`](https://github.com/reichlab/variant-nowcast-hub/blob/main/src/get_target_data.py)

### Dates

There are four important dates used when creating a set of target data:

- `nowcast_date`: The id of a modeling round (defaults to the most recent Wednesday but can be overridden).
- `round_close_date`: The id of the modeling round that is now "closed" because 91 days have passed since
  its nowcast_date (*i.e.*, this round's submissions can now be scored). Calculated as nowcast_date - 91 days.
  This field is used to calculate `as_of` (see below) but is not included in the target data files.
- `as_of`: The SARS-CoV-2 "snapshot" date used when generating target data. Calculated as the round_close_date + 90 days.
- `tree_as_of`: The SARS-CoV-2 [reference tree](https://docs.nextstrain.org/projects/nextclade/en/stable/user/terminology.html#reference-tree-concept)
  in use when the `nowcast_date` modeling round opened, usually nowcast_date - 2 days.
  This field is used for clade assignments when generating target data but is not included in the target data files.

### Values

The target data values (`oracle_value` for oracle data and `observation` for time series) are calculated by:

1. Using the `nowcast_date` to determine other required dates as described above.
2. Downloading the set of SARS-CoV-2 genome sequences that were available on the `as_of` date.
3. Assigning clades to those sequences using the SARS-CoV-2 reference tree in effect on the `tree_as_of` date.
4. Summarizing the number of sequences by location, target date, and clade.

## Oracle output

The hub's oracle output target data are published in parquet format and partitioned by `as_of`, a date in YYYY-MM-DD format.

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

- `as_of`, a date in YYYY-MM-DD format
- `nowcast_date`, a date in YYYY-MM-DD format

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
