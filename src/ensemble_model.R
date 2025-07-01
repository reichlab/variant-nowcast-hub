#' creates and the Hub-ensemble for the week, using all of the submissions that submit samples
#' for the week
require(dplyr)
require(hubUtils)
require(hubEnsembles)
require(arrow)
here::i_am("src/ensemble_model.R")
# setting a seed to ensure reproducibility
set.seed(40900)
# the models used to create the ensemble
input_models <- c("Hub-baseline", "UGA-multicast", "UMass-HMLR", "blab-gisaid_hier_mlr")
# sets the last Wednesday as the date to create the ensemble for
date <- Sys.Date()
offset <- (as.POSIXlt(date)$wday - 3) %% 7
target_date <- date - offset
path_to_model <- "./model-output"
model_df <- data.frame()
# loading in all of the models and giving them unique model_ids
for(i in 1:length(input_models)){
  model_date <- paste(target_date, input_models[i], sep = "-")
  file_path <- file.path(path_to_model,input_models[i], model_date)
  # if no submission for a model on the list, skip to the next model
  if(!file.exists(file.path(paste(file_path, "parquet", sep = ".")))){
    next
  }
  loaded_df <- arrow::read_parquet(paste(file_path, "parquet", sep = "."))
  loaded_df$model_id <- rep(input_models[i], length(loaded_df$nowcast_date))
  model_df <- rbind(model_df, loaded_df)
}
# keeping only the samples
model_df <- filter(model_df, output_type == "sample")
# creating the hub-ensemble
pooled_df <-  hubEnsembles::linear_pool(model_df, n_output_samples = 100, task_id_cols = c("location", "clade", "target_date"),
              compound_taskid_set = c("location"))
# removing the model_id column
pooled_df <- pooled_df[, -1]
model_name <- "Hub-ensemble"
model_date <- paste(target_date, model_name, sep = "-")
file_path <- file.path(path_to_model,model_name, model_date)
# creating the directory if it doesn't exist
if(!file.exists(file.path(path_to_model,model_name))){
  dir.create(file.path(path_to_model,model_name))
}
# saving the predictions
arrow::write_parquet(pooled_df,paste(file_path, "parquet", sep = "."))
