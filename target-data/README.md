# Target Data

The United States SARS-CoV-2 Variant Nowcast Hub generates target data in both oracle output and time series formats
as described in the [Hubverse user guide](https://hubverse.io/en/latest/user-guide/target-data.html).

## Oracle output

The hub's oracle output target data are published in parquet format and partitioned by `as_of`, a date in YYYY-MM-DD format.
Oracle values are calculated by using SARS-CoV-2 sequence data and clade assignments as they existed on
the `as_of` date.

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
