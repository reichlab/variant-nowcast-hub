# Weekly automated scoring script for GitHub Actions
# This script identifies nowcast dates that are 90+ days old and ready for scoring,
# scores all model submissions for those dates, and updates the scores.tsv file incrementally.
#
# Run from /src directory or use here::here() for path resolution

# Load libraries
library(arrow)
library(dplyr)
library(readr)
library(stringr)
library(purrr)
library(lubridate)

# Load scoring functions
source("model_scoring_functions.R")

# Path to Hub root
# Note: here::here() returns the repo root because model_scoring_functions.R
# calls here::i_am("src/model_scoring_functions.R")
hub_path <- here::here()

#' Main function to update scores for recently matured nowcast dates
#'
#' @param hub_path Path to hub root directory
#' @param lookback_days How many days to look back for scoreable nowcasts (default 7)
#' @param min_age_days Minimum age for scoring (default 90)
update_weekly_scores <- function(hub_path = here::here(),
                                  lookback_days = 7,
                                  min_age_days = 90) {

  message("==== Starting Weekly Score Update ====")
  message(sprintf("Date: %s", Sys.Date()))
  message(sprintf("Looking for nowcasts %d-%d days old", min_age_days, min_age_days + lookback_days))

  # Step 1: Identify nowcast dates that are ready to score
  target_nowcast_dates <- identify_scoreable_nowcasts(
    hub_path = hub_path,
    lookback_days = lookback_days,
    min_age_days = min_age_days
  )

  if (length(target_nowcast_dates) == 0) {
    message("✓ No nowcast dates found that need scoring.")
    return(invisible(NULL))
  }

  message(sprintf("Found %d nowcast date(s) to score:", length(target_nowcast_dates)))
  message(paste("  -", target_nowcast_dates, collapse = "\n"))

  # Step 2: Score all models for these nowcast dates
  new_scores <- score_nowcast_dates(
    hub_path = hub_path,
    nowcast_dates = target_nowcast_dates
  )

  if (is.null(new_scores) || nrow(new_scores) == 0) {
    message("✓ No new scores generated (all submissions may have errored).")
    return(invisible(NULL))
  }

  message(sprintf("Generated %d score rows", nrow(new_scores)))

  # Step 3: Update scores.tsv
  update_scores_tsv(
    hub_path = hub_path,
    new_scores = new_scores,
    nowcast_dates = target_nowcast_dates
  )

  message("==== Weekly Score Update Complete ====")
  return(invisible(new_scores))
}

#' Identify nowcast dates that are ready to score
#'
#' @param hub_path Path to hub root
#' @param lookback_days How many days back to check
#' @param min_age_days Minimum age for scoring
#'
#' @return Character vector of nowcast dates (YYYY-MM-DD format)
identify_scoreable_nowcasts <- function(hub_path, lookback_days = 7, min_age_days = 90) {

  # Calculate date range for scoreable nowcasts
  today <- Sys.Date()
  oldest_date <- today - min_age_days - lookback_days
  newest_date <- today - min_age_days

  # Find all model output files
  model_output_dir <- file.path(hub_path, "model-output")
  all_files <- list.files(
    path = model_output_dir,
    pattern = "\\.parquet$",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(all_files) == 0) {
    return(character(0))
  }

  # Extract dates from file names
  file_dates <- str_extract(all_files, "\\d{4}-\\d{2}-\\d{2}") %>%
    na.omit() %>%
    as.character() %>%
    unique() %>%
    as.Date()

  # Filter to dates in our target range
  scoreable_dates <- file_dates[file_dates >= oldest_date & file_dates <= newest_date]

  # Check that required data files exist (oracle and unscored locations)
  valid_dates <- character(0)
  # Convert to character before looping to avoid numeric conversion
  for (date_str in as.character(scoreable_dates)) {

    # Check for oracle data
    oracle_path <- file.path(
      hub_path, "target-data", "oracle-output",
      paste0("nowcast_date=", date_str), "oracle.parquet"
    )

    # Check for unscored locations file
    unscored_path <- file.path(
      hub_path, "auxiliary-data", "unscored-location-dates",
      paste0(date_str, ".csv")
    )

    if (file.exists(oracle_path) && file.exists(unscored_path)) {
      valid_dates <- c(valid_dates, date_str)
    } else {
      message(sprintf("⚠️ Skipping %s: missing oracle or unscored data", date_str))
    }
  }

  return(valid_dates)
}

#' Score all model submissions for given nowcast dates
#'
#' @param hub_path Path to hub root
#' @param nowcast_dates Character vector of nowcast dates to score
#'
#' @return Data frame with columns: model_id, nowcast_date, target_date, location,
#'         brier_point, brier_dist, energy, scored, status
score_nowcast_dates <- function(hub_path, nowcast_dates) {

  all_scores <- list()

  for (nowcast_date in nowcast_dates) {
    message(sprintf("\n--- Scoring nowcast_date: %s ---", nowcast_date))

    # Find all model submissions for this nowcast date
    model_files <- list.files(
      path = file.path(hub_path, "model-output"),
      pattern = paste0(nowcast_date, ".*\\.parquet$"),
      recursive = TRUE,
      full.names = TRUE
    )

    if (length(model_files) == 0) {
      message(sprintf("  No submissions found for %s", nowcast_date))
      next
    }

    message(sprintf("  Found %d model submission(s)", length(model_files)))

    # Score each model submission
    for (model_file in model_files) {

      # Extract model info
      model_id <- basename(dirname(model_file))
      file_name <- basename(model_file)
      relative_path <- file.path(model_id, file_name)

      message(sprintf("    Scoring: %s", model_id))

      # Attempt to score
      tryCatch({

        df_scores <- get_energy_scores(
          hub_path = hub_path,
          model_output_file = relative_path,
          ref_date = nowcast_date
        )

        # Add model_id, nowcast_date, and status
        df_scores <- df_scores %>%
          mutate(
            model_id = model_id,
            nowcast_date = nowcast_date,
            status = NA_character_
          ) %>%
          select(model_id, nowcast_date, target_date, location,
                 brier_point, brier_dist, energy, scored, status)

        all_scores[[length(all_scores) + 1]] <- df_scores

        message(sprintf("      ✓ Scored %d location-date pairs", nrow(df_scores)))

      }, error = function(e) {

        message(sprintf("      ✗ Error: %s", e$message))

        # Create error placeholder row
        error_row <- tibble(
          model_id = model_id,
          nowcast_date = nowcast_date,
          target_date = NA,
          location = NA_character_,
          brier_point = NA_real_,
          brier_dist = NA_real_,
          energy = NA_real_,
          scored = NA,
          status = "error"
        )

        all_scores[[length(all_scores) + 1]] <- error_row
      })
    }
  }

  # Combine all scores
  if (length(all_scores) == 0) {
    return(NULL)
  }

  bind_rows(all_scores)
}

#' Update scores.tsv file with new scores
#'
#' @param hub_path Path to hub root
#' @param new_scores Data frame of new scores to add
#' @param nowcast_dates Character vector of nowcast dates being updated
update_scores_tsv <- function(hub_path, new_scores, nowcast_dates) {

  scores_path <- file.path(hub_path, "auxiliary-data", "scores", "scores.tsv")

  # Read existing scores if file exists
  if (file.exists(scores_path)) {
    message("\nReading existing scores.tsv...")
    existing_scores <- read_tsv(scores_path, show_col_types = FALSE)
    message(sprintf("  Existing rows: %d", nrow(existing_scores)))

    # Remove any existing scores for the nowcast dates we're updating
    # This allows re-running the script to update scores
    existing_scores <- existing_scores %>%
      filter(!(nowcast_date %in% nowcast_dates))

    message(sprintf("  After removing nowcast_dates being updated: %d rows", nrow(existing_scores)))

    # Combine with new scores
    updated_scores <- bind_rows(existing_scores, new_scores)

  } else {
    message("\nNo existing scores.tsv found, creating new file...")
    updated_scores <- new_scores
  }

  # Sort for consistency
  updated_scores <- updated_scores %>%
    arrange(model_id, nowcast_date, target_date, location)

  message(sprintf("  Final row count: %d", nrow(updated_scores)))

  # Write updated scores
  message("Writing updated scores.tsv...")
  write_tsv(updated_scores, scores_path)

  message("✓ scores.tsv updated successfully")
}

# If running directly (not sourced), execute the update
if (!interactive() && !exists("sourced_for_testing")) {
  update_weekly_scores()
}
