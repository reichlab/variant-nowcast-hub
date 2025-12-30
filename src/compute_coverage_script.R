# This script creates energy score data sets for each team/nowcast in Hive format
# Directory paths: auxiliary-data/scores/team=.../nowcast_date=YYYY-MM-DD
# In the event of an error, writes a .log file to the nowcast_date
# Run in /src dir
# There's also a function `combine_scores_tsv` to gather them into a single tsv file

# Load libraries
library(arrow)
library(dplyr)
library(fs)
library(readr)
library(stringr)
library(purrr)

# Load scoring functions
source("model_scoring_functions.R")

# Path to Hub
hub_path <- here::here() # "./" # Use the hub's main directory

# Get list of directories
dirs <- list.dirs(path = "../model-output/", full.names = TRUE, recursive = FALSE)

# Loop over dirs in model-output dir
for(dir in dirs){

  files <- list.files(path = dir ,pattern = "\\.parquet$", full.names = TRUE)
  team <- gsub(".*/(.*)/.*", "\\1", files[1]) # get team name, just need 1st entry

  for(file in files){

    # Extract dates from file names using regex
    date <- gsub(".*/(\\d{4}-\\d{2}-\\d{2})-.*", "\\1", file)

    # logic for dates being 90+ days from today
    if(date > (Sys.Date() - 90)){
      next
    }

    # Trim file name for scoring functions
    trimmed_file_name <- gsub("^\\.\\/model-output\\/\\/", "", file)

    # Write the results to a new parquet file in a different location
    # Hive style formatting
    # Directory path: auxiliary-data/coverage/team=.../nowcast_date=YYYY-MM-DD
    save_dir_path <- file.path(hub_path,
                               "auxiliary-data",
                               "coverage",
                               paste0("team=", team),
                               paste0("nowcast_date=", date))

    # If directory doesn't exist, then create it
    if (!file.exists(save_dir_path))
      dir.create(save_dir_path, recursive = TRUE)

    # If save_dir_path is empty, start the scoring functions
    if (length(list.files(save_dir_path)) == 0){

      tryCatch({
        # Calculate coverage
        df_coverage <- get_coverage(hub_path = hub_path,
                                       model_output_file = trimmed_file_name,
                                       ref_date = date)

        # Write to parquet
        write_parquet(df_coverage, file.path(save_dir_path, "coverage_nowcast.parquet"))

      }, error = function(e) {
        message(sprintf("⚠️ Error in '%s' for team '%s' on date '%s': %s",
                        trimmed_file_name, team, date, e$message))
        # Write a log file if an error occurs (or create a placeholder)
        writeLines(e$message, file.path(save_dir_path, "error.log"))
      })
    }
  }
}

#' Function to gather scores into tsv format from Hive format, accounting for any error.log files
#'
#' @param hub_path character string, path to the root of the hub from the current working directory,
#' defaults to assume that variant-nowcast-hub/src is the working directory
#'
#' @examples combine_coverage_parquet()
combine_coverage_parquet <- function(hub_path = "../"){
  # Define the root directory of your Hive-partitioned dataset
  root_dir <- file.path(hub_path, "auxiliary-data", "coverage")

  # Helper to extract team and nowcast_date from path
  extract_metadata <- function(path) {
    tibble(
      team = str_extract(path, "team=[^/]+") |> str_remove("team="),
      nowcast_date = str_extract(path, "nowcast_date=\\d{4}-\\d{2}-\\d{2}") |> str_remove("nowcast_date=")
    )
  }

  # Find all coverage_nowcast.parquet files
  parquet_files <- dir_ls(root_dir, recurse = TRUE, type = "file", glob = "*_nowcast.parquet")

  # Read and tag each parquet file
  coverage_df <- map_dfr(parquet_files, function(file) {
    meta <- extract_metadata(file)
    df <- read_parquet(file)
    bind_cols(meta, status = "success", df)
  })

  # Find all error.log files
  error_files <- dir_ls(root_dir, recurse = TRUE, type = "file", glob = "*.log")

  # Create placeholder rows for errors
    error_df <- map_dfr(error_files, function(file) {
      meta <- extract_metadata(file)
      tibble(
        model_id = meta$team,
        nowcast_date = meta$nowcast_date,
        location = NA_character_,
        target_date = NA,
        scored = NA,
        clade = NA_character_,
        quantile_level = NA_real_,
        interval_range = NA_real_,
        interval_coverage = NA_real_,
        interval_coverage_devation = NA_real_,
        quantile_coverage = NA_real_,
        quantile_coverage_deviation = NA_real_,
        status = "error"
      )
    })

  # Combine both
  final_df <- bind_rows(coverage_df, error_df)

  # Arrange columns
    final_df <- final_df[, c("team",
                              "nowcast_date",
                              "target_date",
                              "location",
                              "clade",
                              "quantile_level",
                             "interval_range",
                             "interval_coverage",
                             "interval_coverage_devation",
                             "quantile_coverage",
                             "quantile_coverage_deviation",
                              "scored",
                              "status"
    )] |> rename(model_id = team)

  # Write to parquet
  arrow::write_parquet(final_df, glue::glue("../auxiliary-data/coverage/coverage.parquet"))
}
