## Create energy score data sets for each nowcast
# Run in /src dir

# Load libraries
library(arrow)
library(dplyr)

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
    # Directory path: auxiliary-data/scores/team=.../nowcast_date=YYYY-MM-DD
    save_dir_path <- file.path(hub_path,
                               "auxiliary-data",
                               "scores",
                               paste0("team=", team),
                               paste0("nowcast_date=", date))

    # if directory doesn't exist, then create it
    if (!file.exists(save_dir_path))
      dir.create(save_dir_path, recursive = TRUE)

    # If save_dir_path is empty, start the scoring functions
    if (length(list.files(save_dir_path)) == 0){

      # Calculate scores (outputs a data frame)
      df_scores <- get_energy_scores(hub_path = hub_path,
                                     model_output_file = trimmed_file_name,
                                     ref_date = date)

      write_parquet(df_scores, file.path(save_dir_path, "scored_nowcast.parquet"))
    }
  }
}
