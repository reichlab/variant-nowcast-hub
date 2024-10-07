## Script that generates sample submission data to pass validation checks
require(arrow) # for parquet writing

# Function found in /src to generate data frame
df_sim <- sim_model_output()

# Note: make sure to point to the correct path for your data, defaults to folder 'model-output'
arrow::write_parquet(df_sim, "./2024-10-02-umass-validtestsubmission.parquet")
hubValidations::validate_model_data("./variant-nowcast-hub", 
                                    "2024-10-02-umass-validtestsubmission.parquet")