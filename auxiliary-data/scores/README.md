# *Scored Nowcast Submissions*

This document provides details regarding the scored submissions (`scored.tsv`) for the 
United States SARS-CoV-2 Variant Nowcast Hub, which launched on October 9, 2024.

Please refer to [model evaluation](https://github.com/reichlab/variant-nowcast-hub?tab=readme-ov-file#model-evaluation)
for additional context.

The `scores.tsv` file contains all location/date scores for each model submission. 
This file will be updated weekly as target data is available for scoring.

### Column Values in `scores.tsv`

- `model_id`: The team model/submission name
- `nowcast_date`: the date of the Wednesday submission deadline, in `YYYY-MM-DD` format.
- `target_date`: the date that a specific nowcast prediction is made for, in `YYYY-MM-DD` format.
- `location`: the two-letter abbreviation for a US state, including DC and PR for Washington DC and Puerto Rico.
- `brier_point`: the Brier score of the mean clade proportions (point estimate) for this `location` and `target_date`:
  - If a model submitted output_type `mean`, it is the Brier score of this mean. 
  - If a model submitted `sample`s but no `mean`, it is the Brier score of the mean of the 100 samples.
- `brier_dist`: the average Brier score (score across the provided sample distribution) of all 100 samples:
  - This is `NA` for models that do not submit `sample`s.
  - Note: In principle, by Jensen's inequality, it's expected that the `brier_point` scores
  are always less than or equal to the `brier_dist` scores. However, analysis has shown that 
  due to instances where submitted means may be based on samples not included on the 100 submitted 
  for `sample` submissions, there exist observations where this statement is not true.
- `energy`: the energy score for this `location` and `target_date`:
  - This is only available for models that submit `sample`s.
- `scored`: whether this `location` and `target_date` pair should be scored according 
to the Hub schema - see [model evaluation](https://github.com/reichlab/variant-nowcast-hub?tab=readme-ov-file#model-evaluation) for more details.
  - `TRUE`: no partial observations were available during the nowcast period.
  - `FALSE`: partial observations were available during the nowcast period and so
  this observation may be excluded from final evaluation.
- `status`: indicates whether the scoring was successful or not. This is a 
byproduct of a failed validation check that only affects a few model submissions - 
see the `error` outcomes for which ones these are. Issue to be filed with hubValidations. 
The majority of submissions had no trouble, indicated by `success`.

### Example

To get a data frame in R of all model submissions that should be scored according
to the Hub schema: in the repo directory, use
`df <- read_tsv("./auxiliary-data/scores/scores.tsv") |> filter(scored == T)`

# *Coverage of Nowcast Submissions*

This document provides details regarding the coverage metrics for the submissions (`coverage.parquet`) for the 
United States SARS-CoV-2 Variant Nowcast Hub, which launched on October 9, 2024.

Please refer to [model evaluation](https://github.com/reichlab/variant-nowcast-hub?tab=readme-ov-file#model-evaluation)
for additional context.



The `coverage.parquet` file contains all location/date/clade/interval coverage values for each model submission. 
This file will be updated weekly as target data is available to compute coverage.

### Column Values in `coverage.parquet`

- `model_id`: The team model/submission name
- `nowcast_date`: the date of the Wednesday submission deadline, in `YYYY-MM-DD` format.
- `target_date`: the date that a specific nowcast prediction is made for, in `YYYY-MM-DD` format.
- `location`: the two-letter abbreviation for a US state, including DC and PR for Washington DC and Puerto Rico.
- `clade`: the alpha-numeric clade designation
- `quantile_level`: the probability level of the quantile (e.g., 0.25, 0.75). Each prediction interval is defined by two quantiles. 
- `interval_range`: the nomincal coverage level of the prediction interval (e.g., 50 for a 50% interval formed by the 0.25 and 0.75 quantiles).
- `interval_coverage`: the empirical coverage- the proportion of times the observed value fell within the prediction interval at that level. Note this will always be 0, 1, or NA, because for each nwocast date, target date, location, and clade there is a single observed proportion which either falls within the prediction interval (1) or outside of it (0). It will be NA if there were no sequences collected on that target date in that location as of the evaluation date. 
- `quantile_coverage`: the empirical coverage at the quantile level- the proportion of times the observed value was below the predicted quantile. Again, this will always be 0, 1, or NA by the same logic as the `interval_coverage`.
- `quantile_coverage_deviation`: the difference between empirical and nominal quantile coverage (`quantile_coverage`- `quantile_level`). For a well-calibrated forecast, observe values should be below the predicted quantile with probability equal to the quantile level.
- `scored`:  whether this `location` and `target_date` pair should be scored according 
to the Hub schema - see [model evaluation](https://github.com/reichlab/variant-nowcast-hub?tab=readme-ov-file#model-evaluation) for more details.
  - `TRUE`: no partial observations were available during the nowcast period.
  - `FALSE`: partial observations were available during the nowcast period and so
   this observation may be excluded from final evaluation.
- `status`: indicates whether the scoring was successful or not. This is a 
byproduct of a failed validation check that only affects a few model submissions - 
see the `error` outcomes for which ones these are. Issue to be filed with hubValidations. 
The majority of submissions had no trouble, indicated by `success`.

### Example

To get a data frame in R of coverage values for all model submissions that are scored:
in the repo directory, use
`df <- arrow::read_parquet("./auxiliary-data/scores/coverage.parquet") |> filter(scored == T)`
