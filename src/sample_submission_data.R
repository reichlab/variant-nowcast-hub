## Script that generates sample submission data to pass validation checks
here::i_am("src/sample_submission_data.R")
library("arrow") # for parquet writing
source(here::here('src/sim_model_output.R'))
# Function found in /src to generate data frame
df_sim <- sim_model_output()

# Note: make sure to point to the correct path for your data, defaults to folder 'model-output'
arrow::write_parquet(df_sim, here::here("auxiliary-data/example-files/2024-10-02-umass-validtestsubmission.parquet"))
hubValidations::validate_model_data(here::here(), "2024-10-02-umass-validtestsubmission.parquet")
