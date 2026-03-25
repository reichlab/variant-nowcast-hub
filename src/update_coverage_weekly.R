# Weekly automated coverage calculation script for GitHub Actions
# This script syncs coverage.parquet with scores.tsv by calculating coverage
# for any nowcast dates that have been scored but don't have coverage yet.
#
# Run from /src directory or use here::here() for path resolution

# Load libraries
library(arrow)
library(dplyr)
library(readr)
library(stringr)
library(purrr)
library(lubridate)

# Load scoring functions (includes get_coverage)
source("model_scoring_functions.R")

# Path to Hub root
# Note: here::here() returns the repo root because model_scoring_functions.R
# calls here::i_am("src/model_scoring_functions.R")
hub_path <- here::here()

#' Main function to update coverage by syncing with scores.tsv
#'
#' @param hub_path Path to hub root directory
update_weekly_coverage <- function(hub_path = here::here()) {

  message("==== Starting Weekly Coverage Update ====")
  message(sprintf("Date: %s", Sys.Date()))

  # Step 1: Identify nowcast dates that need coverage
  target_nowcast_dates <- identify_missing_coverage(hub_path = hub_path)

  if (length(target_nowcast_dates) == 0) {
    message("✓ Coverage is already in sync with scores.tsv")
    return(invisible(NULL))
  }

  message(sprintf("Found %d nowcast date(s) needing coverage:", length(target_nowcast_dates)))
  message(paste("  -", target_nowcast_dates, collapse = "\n"))

  # Step 2: Calculate coverage for these nowcast dates
  new_coverage <- calculate_coverage_for_dates(
    hub_path = hub_path,
    nowcast_dates = target_nowcast_dates
  )

  if (is.null(new_coverage) || nrow(new_coverage) == 0) {
    message("✓ No new coverage generated (all submissions may have errored).")
    return(invisible(NULL))
  }

  message(sprintf("Generated %d coverage rows", nrow(new_coverage)))

  # Step 3: Update coverage.parquet
  update_coverage_parquet(
    hub_path = hub_path,
    new_coverage = new_coverage,
    nowcast_dates = target_nowcast_dates
  )

  message("==== Weekly Coverage Update Complete ====")
  return(invisible(new_coverage))
}

#' Identify nowcast dates that are in scores.tsv but missing from coverage.parquet
#'
#' @param hub_path Path to hub root
#'
#' @return Character vector of nowcast dates (YYYY-MM-DD format)
identify_missing_coverage <- function(hub_path) {

  scores_path <- file.path(hub_path, "auxiliary-data", "scores", "scores.tsv")
  coverage_path <- file.path(hub_path, "auxiliary-data", "scores", "coverage.parquet")

  # Read scores.tsv to get all scored nowcast dates
  if (!file.exists(scores_path)) {
    message("⚠️ scores.tsv not found!")
    return(character(0))
  }

  scores <- read_tsv(scores_path, show_col_types = FALSE)
  scored_dates <- unique(scores$nowcast_date[!is.na(scores$nowcast_date)])
  # Convert to character to avoid Date type issues
  scored_dates <- as.character(scored_dates)

  message(sprintf("Found %d scored nowcast_dates in scores.tsv", length(scored_dates)))

  # Read coverage.parquet to get already-covered dates
  covered_dates <- character(0)
  if (file.exists(coverage_path)) {
    coverage <- read_parquet(coverage_path)
    covered_dates <- unique(coverage$nowcast_date[!is.na(coverage$nowcast_date)])
    # Convert to character
    covered_dates <- as.character(covered_dates)
    message(sprintf("Found %d nowcast_dates in coverage.parquet", length(covered_dates)))
  } else {
    message("coverage.parquet not found - will create new file")
  }

  # Find missing dates
  missing_dates <- setdiff(scored_dates, covered_dates)
  missing_dates <- sort(missing_dates)

  return(missing_dates)
}

#' Calculate coverage for specific nowcast dates
#'
#' @param hub_path Path to hub root
#' @param nowcast_dates Character vector of nowcast dates to calculate coverage for
#'
#' @return Data frame with columns: model_id, nowcast_date, target_date, location,
#'         clade, quantile_level, interval_range, interval_coverage,
#'         quantile_coverage, quantile_coverage_deviation, scored, status
calculate_coverage_for_dates <- function(hub_path, nowcast_dates) {

  all_coverage <- list()

  # IMPORTANT: Convert to character BEFORE looping to avoid Date->numeric conversion
  for (nowcast_date in as.character(nowcast_dates)) {
    message(sprintf("\n--- Calculating coverage for nowcast_date: %s ---", nowcast_date))

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

    # Calculate coverage for each model submission
    for (model_file in model_files) {

      # Extract model info
      model_id <- basename(dirname(model_file))
      file_name <- basename(model_file)
      relative_path <- file.path(model_id, file_name)

      message(sprintf("    Calculating: %s", model_id))

      # Attempt to calculate coverage
      tryCatch({

        df_coverage <- get_coverage(
          hub_path = hub_path,
          model_output_file = relative_path,
          ref_date = nowcast_date
        )

        # Check if get_coverage returned NULL (for non-sample submissions)
        if (is.null(df_coverage)) {
          message(sprintf("      ⊘ No samples (coverage not applicable)"))
          next
        }

        # Add model_id, nowcast_date, and status
        # IMPORTANT: Keep nowcast_date as character to match existing coverage.parquet
        df_coverage <- df_coverage %>%
          mutate(
            model_id = model_id,
            nowcast_date = as.character(nowcast_date),
            status = NA_character_
          ) %>%
          select(model_id, nowcast_date, target_date, location, clade,
                 quantile_level, interval_range, interval_coverage,
                 quantile_coverage, quantile_coverage_deviation, scored, status)

        all_coverage[[length(all_coverage) + 1]] <- df_coverage

        message(sprintf("      ✓ Calculated %d coverage rows", nrow(df_coverage)))

      }, error = function(e) {

        message(sprintf("      ✗ Error: %s", e$message))

        # Create error placeholder row
        # IMPORTANT: Keep nowcast_date as character to match existing coverage.parquet
        error_row <- tibble(
          model_id = model_id,
          nowcast_date = as.character(nowcast_date),
          target_date = as.Date(NA),
          location = NA_character_,
          clade = NA_character_,
          quantile_level = NA_real_,
          interval_range = NA_real_,
          interval_coverage = NA_real_,
          quantile_coverage = NA_real_,
          quantile_coverage_deviation = NA_real_,
          scored = NA,
          status = "error"
        )

        all_coverage[[length(all_coverage) + 1]] <- error_row
      })
    }
  }

  # Combine all coverage
  if (length(all_coverage) == 0) {
    return(NULL)
  }

  bind_rows(all_coverage)
}

#' Update coverage.parquet file with new coverage data
#'
#' @param hub_path Path to hub root
#' @param new_coverage Data frame of new coverage to add
#' @param nowcast_dates Character vector of nowcast dates being updated
update_coverage_parquet <- function(hub_path, new_coverage, nowcast_dates) {

  coverage_path <- file.path(hub_path, "auxiliary-data", "scores", "coverage.parquet")

  # Read existing coverage if file exists
  if (file.exists(coverage_path)) {
    message("\nReading existing coverage.parquet...")
    existing_coverage <- read_parquet(coverage_path)
    message(sprintf("  Existing rows: %d", nrow(existing_coverage)))

    # Remove any existing coverage for the nowcast dates we're updating
    # This allows re-running the script to update coverage
    # IMPORTANT: Keep as character for comparison (matches existing format)
    existing_coverage <- existing_coverage %>%
      filter(!(nowcast_date %in% nowcast_dates))

    message(sprintf("  After removing nowcast_dates being updated: %d rows", nrow(existing_coverage)))

    # Combine with new coverage
    updated_coverage <- bind_rows(existing_coverage, new_coverage)

  } else {
    message("\nNo existing coverage.parquet found, creating new file...")
    updated_coverage <- new_coverage
  }

  # Sort for consistency
  updated_coverage <- updated_coverage %>%
    arrange(model_id, nowcast_date, target_date, location, clade, quantile_level)

  message(sprintf("  Final row count: %d", nrow(updated_coverage)))

  # Write updated coverage
  message("Writing updated coverage.parquet...")
  write_parquet(updated_coverage, coverage_path)

  message("✓ coverage.parquet updated successfully")
}

# If running directly (not sourced), execute the update
if (!interactive() && !exists("sourced_for_testing")) {
  update_weekly_coverage()
}
