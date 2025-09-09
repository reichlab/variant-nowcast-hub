#' creates and the Hub-ensemble for the week, using all of the submissions that submit samples
#' for the week
require(dplyr)
require(hubUtils)
require(hubEnsembles)
require(arrow)
require(hubData)
here::i_am("src/ensemble_model.R")
# setting a seed to ensure reproducibility
set.seed(40900)
# sets the last Wednesday as the date to create the ensemble for by taking the current day,
# finding what day of the week it is, and subtracting an offset to find the last Wednesday
date <- Sys.Date()
offset <- (as.POSIXlt(date)$wday - 3) %% 7
file_date <- date - offset
path_to_model <- "../model-output"
bucket_name <- "covid-variant-nowcast-hub"
hub_bucket <- hubData::s3_bucket(bucket_name)
hub_con <- hubData::connect_hub(hub_bucket, file_format = "parquet", skip_checks = TRUE)
# loading in all of the models that contain samples for the week
model_df <- hub_con %>%
  dplyr::filter(nowcast_date == file_date, output_type == "sample") %>%
  hubData::collect_hub() %>%
  dplyr::select(model_id, nowcast_date, target_date, location, clade, value, output_type, output_type_id)
# creating the hub-ensemble
pooled_df <- hubEnsembles::linear_pool(
  model_df,
  n_output_samples = 100,
  task_id_cols = c("location", "clade", "target_date"),
  compound_taskid_set = c("location"))
# removing the model_id column
pooled_df <- pooled_df[, -1]
# creating the path to save the model at
model_name <- "Hub-ensemble"
model_date <- paste(file_date, model_name, sep = "-")
file_path <- file.path(path_to_model,model_name, model_date)
# creating the directory if it doesn't exist
if(!file.exists(file.path(path_to_model,model_name))){
  dir.create(file.path(path_to_model,model_name))
}
# saving the predictions
arrow::write_parquet(pooled_df,paste(file_path, "parquet", sep = "."))
