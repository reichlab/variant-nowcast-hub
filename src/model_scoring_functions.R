#' Functions to calculate energy scores for model output files according to given reference date
#'
#' @param hub_path character string, path to the root of the hub from the current working directory,
#' defaults to assume that variant-nowcast-hub/src is the working directory
#' @param model_output_file character string, directory under variant-nowcast-hub/[team name]/[model output parquet file]
#' @param ref_date character string, date corresponding to model submission deadline, also called nowcast date
#'
#' @examples
#' source("model_scoring_functions.R")
#' df_score <- get_energy_scores(hub_path = here::here(), model_output_file = "UMass-HMLR/2024-12-18-UMass-HMLR.parquet", ref_date = "2024-12-18")
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

  # Extract the date from model_output_file for set.seed using regex
  date_str <- sub(".*?(\\d{4}-\\d{2}-\\d{2}).*", "\\1", model_output_file)

  # Remove dashes to get a numeric sequence string
  date_str <- gsub("-", "", date_str)

  # Set PRNG seed for reproducibility
  set.seed(as.integer(date_str))

  data <- process_target_data(hub_path = hub_path,
                              model_output_file = model_output_file,
                              ref_date = as.Date(ref_date))

  df_scores <- calc_energy_scores(targets = data[[1]],
                                  df_model_output = data[[2]])

  return(df_scores)
}

#' Support function to process target data and pass to scoring function.
#'
#' @param hub_path character string, path to the root of the hub from the current working directory,
#' defaults to assume that variant-nowcast-hub/src is the working directory
#' @param model_output_file character string, directory under variant-nowcast-hub/[team name]/[model output parquet file]
#' @param ref_date character string, date corresponding to model submission deadline, also called nowcast date
#'
#' @return List of two data frames. First element is the target data, second element is the model_output data
process_target_data <- function(hub_path = here::here(),
                                model_output_file,
                                ref_date){
  # Load model output
  df_model_output <- arrow::read_parquet(file.path(hub_path, "model-output", model_output_file)) |>
    arrange(location, target_date, output_type_id, clade)
  locs_modeled <- sort(unique(df_model_output$location))

  # Load validation data
  oracle_file <- paste0("nowcast_date=", ref_date)
  oracle_path <- file.path(hub_path, "target-data", "oracle-output",
                           oracle_file, "oracle.parquet")
  df_validation <- arrow::read_parquet(oracle_path)

  # Pick out dates to score that were not used for any training
  unscored_file <- paste0(ref_date, ".csv")
  unscored_path <- file.path(hub_path, "auxiliary-data", "unscored-location-dates", unscored_file)
  df_unscored <-
    read_csv(unscored_path, show_col_types = FALSE) |>
    # Add T/F whether location should be scored according to Hub scheme
    mutate(scored = ifelse(count > 0, FALSE, TRUE)) |> # TRUE when there is NOT data present during the nowcast period as of submission period
    select(location, target_date, scored) # Only covers nowcast dates, not forecast

  targets <- df_validation |>
    filter(target_date > (as.Date(ref_date) - 32)) |>
    filter(location %in% locs_modeled) |>
    arrange(location, target_date, clade) |>
    left_join(df_unscored, by = join_by(location, target_date)) |> # Unique keys: target_date and location
    mutate(scored = coalesce(scored, TRUE))  # default non-matches to TRUE - i.e the forecast dates are scored

  # For testing:
  # browser() # e.g.: targets <- targets |> filter(location == "AZ") then type `c` to continue
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
  score_list <- list() # list to keep track of scores

  locs <- sort(unique(targets$location))
  dates <- sort(unique(targets$target_date))

  # Loop over each day at each location
  for(loc in locs){
    for(day in dates){

      # Default values of scores
      es <- NA_real_
      brier_point <- NA_real_
      brier_dist <- NA_real_

      # Validated observed counts
      df_obs <- targets |>
        filter(target_date == as.Date(day), location == loc)
      scored <- df_obs$scored[1] # To track scored date/loc pair for return

      # Observed counts by clade
      obs_count <- df_obs$oracle_value

      # If the observed counts are all 0, add NA ES
      if( sum(obs_count) == 0 ){
        score_list[[length(score_list) + 1]] <- data.frame(
          energy = NA_real_,
          brier_point = NA_real_,
          brier_dist = NA_real_,
          location = loc,
          target_date = as.Date(day),
          scored = scored
        )
        next
      }

      # Need the N for each loc/day from the validation data
      N <- sum(subset(targets,
                      location == loc & target_date == as.Date(day))$oracle_value)

      # MCMC sample of modeled COUNTS
      if("sample" %in% unique(df_model_output$output_type)){
        df_samp <- subset(df_model_output,
                          target_date == as.Date(day) &
                            location == loc &
                            output_type == "sample")

        # Pivot wider to get to MCMC format for scoring
        df_samp_wide <- pivot_wider(df_samp, names_from = output_type_id, values_from = value)
        df_samp_wide <- subset(df_samp_wide,
                               select = -c(nowcast_date, target_date,
                                           clade, location, output_type))

        # Convert samples to matrix for scoringRules syntax
        samp_matrix <- as.matrix(df_samp_wide)

        ## Implement Multinomial Sampling from the proportions
        ## Score on counts

        # Matrix to store 100 multinomial samples generated from each of 100 sample props
        samp_multinomial_counts <- do.call(cbind, lapply(1:ncol(samp_matrix), function(col) {
          rmultinom(n = 100, size = N, prob = samp_matrix[, col])
        }))

        # Energy score for the 100*100 multinomial samples for day/loc
        es <- es_sample(y = obs_count, dat = samp_multinomial_counts)
      }

      # Brier scores

      if("mean" %in% unique(df_model_output$output_type)){
        # If output_type == "mean" present
        df_mean <- subset(df_model_output,
                          target_date == as.Date(day) &
                            location == loc &
                            output_type == "mean")

        # Brier score calculation for the mean
        # Divide by 2 to get range [0,1]
        brier_point <- 0.5 / N * sum(obs_count*(df_mean$value - 1)^2 + (N - obs_count)*(df_mean$value)^2)

      } else{
        # If no output_type == "mean" present
        df_mean <- df_samp |>
          group_by(clade) |> # Group by clade to calculate mean of each one, already arranged
          summarise(mean_value = mean(value, na.rm = T))
        brier_point <- 0.5 / N * sum(obs_count*(df_mean$mean_value - 1)^2 + (N - obs_count)*(df_mean$mean_value)^2)
      }

      # Brier distribution scores
      if("sample" %in% unique(df_model_output$output_type)){
        brier_dist <- apply(df_samp_wide, 2, function(p_col) {
          sum(obs_count * (p_col - 1)^2 + (N - obs_count) * p_col^2)
        })
        brier_dist <- 0.5 * mean(brier_dist) / N
      }

      # Store scores as a data frame but to a list
      score_list[[length(score_list) + 1]] <- data.frame(
        energy = es,
        brier_point = brier_point,
        brier_dist = brier_dist,
        location = loc,
        target_date = as.Date(day),
        scored = scored
      )
    }
  }
  # bind rows of data frames in scores_list (faster than appending)
  return(dplyr::bind_rows(score_list))
}

#' Function to quickly get some summaries of the energy scores
#' @param df_scores a data frame containing energy scores created by [calc_energy_scores]
#'
#' @return Returns a list: first element is the mean energy score across all dates/locations.
#' The second element is a table summarizing the mean energy score by location.
#' The third element is a table summarizing the mean energy score by date.
energy_summary <- function(df_scores){
  # Calculate overall energy score
  mean_score <- mean(df_scores$energy, na.rm = TRUE)

  # Calculate ES by location
  tbl_scores_loc <- df_scores |>
    group_by(location) |>
    summarise(mean_score=mean(energy, na.rm = TRUE))

  # Calculate ES by date
  tbl_scores_date <- df_scores |>
    group_by(target_date) |>
    summarise(mean_score=mean(energy, na.rm = TRUE))

  return(list(mean_score, tbl_scores_loc, tbl_scores_date))
}
