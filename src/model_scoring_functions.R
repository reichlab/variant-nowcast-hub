#' Functions to calculate energy scores for model output files according to given reference date
#'
#' @param hub_path character string, path to the root of the hub from the current working directory,
#' defaults to assume that variant-nowcast-hub/src is the working directory
#' @param model_output_file character string, directory under variant-nowcast-hub/[team name]/[model output parquet file]
#' @param ref_date character string, date corresponding to model submission deadline, also called nowcast date
#'
#' @examples
#' source("model_scoring_functions.R")
#' df_score <- get_energy_scores(hub_path = here::here(), model_output_file = "UMass-HMLR/2024-10-16-UMass-HMLR.parquet",
#' ref_date = "2024-10-16")
here::i_am("src/model_scoring_functions.R")
get_energy_scores <- function(
    hub_path = here::here(),
    model_output_file = NULL,
    ref_date = NULL
){
  require("tidyr")
  require("dplyr")
  require("readr")
  require("arrow")
  require("scoringRules")
  
  data <- process_target_data(hub_path = hub_path,
                              model_output_file = model_output_file,
                              ref_date = as.Date(ref_date))
  
  df_scores <- calc_energy_scores(targets = data[[1]],
                                  df_model_output = data[[2]])
  
  return(df_scores)
}

#' Support function to process target data and pass to scoring function.
#'
#' @param hub_path haracter string, path to the root of the hub from the current working directory,
#' defaults to assume that variant-nowcast-hub/src is the working directory
#' @param model_output_file character string, directory under variant-nowcast-hub/[team name]/[model output parquet file]
#' @param ref_date character string, date corresponding to model submission deadline, also called nowcast date
#'
#' @return List of two data frames. First element is the target data, second element is the model_output data
process_target_data <- function(hub_path = here::here(),
                                model_output_file,
                                ref_date){
  # Load model output
  df_model_output <- arrow::read_parquet(file.path(hub_path, "model-output", model_output_file))
  locs_modeled <- sort(unique(df_model_output$location))
  
  # Load validation data
  oracle_file <- paste0("nowcast_date=", ref_date)
  oracle_path <- file.path(hub_path, "target-data", "oracle-output",
                           oracle_file, "oracle.parquet")
  df_validation <- arrow::read_parquet(oracle_path)
  
  # Pick out dates to score that were not used for any training
  unscored_file <- paste0(ref_date, ".csv")
  unscored_path <- file.path(hub_path, "auxiliary-data", "unscored-location-dates", unscored_file)
  df_unscored <- read_csv(unscored_path,
                          show_col_types = FALSE)
  
  # Load location data to match abbreviations to full name locations
  load(file.path(hub_path, "auxiliary-data", "hub_locations.rda"))
  locs_join <- hub_locations |>
    dplyr::select(abbreviation, location_name) |>
    rename(location = location_name)
  
  df_unscored <- df_unscored |>
    left_join(locs_join, by = c("location" = "location")) |>
    select(abbreviation, target_date, count) |>
    rename(location = abbreviation)
  
  targets <- df_validation
  
  # Max forecast date
  forecast_date <- ref_date + 10
  
  # Keep all forecast data
  targets_forecast_temp <- targets |>
    subset(target_date > ref_date & target_date <= forecast_date)
  
  # Nowcast temp data frame to be refined
  targets_nowcast_temp <- targets |>
    subset(target_date <= ref_date)
  
  # Join by target_date and location - keeping only those
  # Merging "unscored" location data with full target data
  # Need only be done for dates <= ref_date
  targets_nowcast_temp <- targets_nowcast_temp |>
    right_join(y = df_unscored_zeros, by = join_by(target_date, location)) |>
    select(-count)
  
  # Combine refined nowcast data with forecast data
  targets <- rbind(targets_nowcast_temp, targets_forecast_temp) |>
    subset(location %in% locs_modeled) |>
    arrange(location, target_date)
  
  return(list(targets, df_model_output))
}

#' Support function for calculating energy scores given target and model_output data
#'
#' @param targets data frame, of target data
#' @param df_model_output data frame, of model output
#'
#' @return Returns a data frame containing energy scores by location and date
calc_energy_scores <- function(targets, df_model_output){
  # Energy Scores
  columns <- c("es_score", "location", "target_date")
  df_scores <- data.frame(matrix(nrow = 0, ncol = length(columns)))
  colnames(df_scores) <- columns
  
  locs <- sort(unique(targets$location))
  dates <- sort(unique(targets$target_date))
  
  # Loop over each day at each location
  for(loc in locs){
    for(day in dates){
      
      # For debugging and satisfaction
      # print(loc)
      # print(as.Date(day))
      
      # Storage for ES
      es <- as.numeric()
      
      # Validated observed counts
      df_obs <- subset(targets, target_date == as.Date(day) & location == loc) |>
        group_by(clade)
      
      # If there is no such observation, skip to next day
      if( nrow(df_obs) == 0 ){
        next
      }
      
      # Observed counts by clade
      obs_count <- df_obs$oracle_value
      
      # If the observed counts are all 0, add NA ES
      if( sum(obs_count) == 0 ){
        df_temp <- as.data.frame(x = list(NA, loc, as.Date(day)),
                                 col.names = columns)
        df_scores <- rbind(df_scores, df_temp)
        next
      }
      
      # MCMC sample of modeled COUNTS
      df_samp <- subset(df_model_output,
                        target_date == as.Date(day) &
                          location == loc &
                          output_type == "sample") |>
        group_by(clade)
      
      # Pivot wider to get to MCMC format for scoring
      df_samp_wide <- pivot_wider(df_samp, names_from = output_type_id, values_from = value) |>
        group_by(clade)
      df_samp_wide <- subset(df_samp_wide,
                             select = -c(nowcast_date, target_date,
                                         clade, location, output_type))
      
      # Convert samples to matrix for scoringRules syntax
      samp_matrix <- as.matrix(df_samp_wide)
      
      ## Implement Multinomial Sampling from the proportions
      ## SCORE ON COUNTS
      
      # Matrix to store 100 multinomial samples generated from each of 100 sample props
      samp_multinomial_counts <- matrix(nrow = dim(samp_matrix)[1], ncol = 0)
      
      # Need the N for each loc/day from the validation data
      N <- sum(subset(targets,
                      location == loc & target_date == as.Date(day))$oracle_value)
      
      # Generate 100 multinomial counts for each proportions col of samp_matrix
      for(col in 1:dim(samp_matrix)[2]){
        
        # Get sample clade proportions from predictive distribution
        samp_props <- samp_matrix[,col]
        
        # Generate 100 multinomial observations from samp_props
        samp_counts <- rmultinom(n = 100, size = N, prob = samp_props)
        
        # Append each multinomial sample together for 10000 total
        samp_multinomial_counts <- cbind(samp_multinomial_counts, samp_counts)
        
      }
      
      # Energy score for the 100*100 multinomial samples for day/loc
      es <- es_sample(y = obs_count, dat = samp_multinomial_counts)
      
      # Store energy scores to data frame
      df_temp <- as.data.frame(x = list(es, loc, as.Date(day)),
                               col.names = columns)
      df_scores <- rbind(df_scores, df_temp)
    }
  }
  return(df_scores)
}

#' Function to quickly get some summaries of the energy scores
#' @param df_scores a data frame containing energy scores created by [calc_energy_scores]
#'
#' @return Returns a list: first element is the mean energy score across all dates/locations.
#' The second element is a table summarizing the mean energy score by location.
#' The third element is a table summarizing the mean energy score by date.
energy_summary <- function(df_scores){
  # Calculate overall energy score
  mean_score <- mean(df_scores$es_score, na.rm = TRUE)
  
  # Calculate ES by location
  tbl_scores_loc <- df_scores |>
    group_by(location) |>
    summarise(mean_score=mean(es_score, na.rm = TRUE))
  
  # Calculate ES by date
  tbl_scores_date <- df_scores |>
    group_by(target_date) |>
    summarise(mean_score=mean(es_score, na.rm = TRUE))
  
  return(list(mean_score, tbl_scores_loc, tbl_scores_date))
}
