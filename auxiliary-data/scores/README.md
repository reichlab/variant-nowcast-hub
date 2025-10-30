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
`df <- read_tsv("./auxiliary-data/scores/scores.tsv") |> filter(scored = T)`
