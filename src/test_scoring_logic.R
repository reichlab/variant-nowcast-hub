# Comprehensive test of scoring logic
# This simulates exactly what happens in GitHub Actions

# Set working directory to src/ (like GitHub Actions does)
setwd("src")
cat("===== COMPREHENSIVE SCORING TEST =====\n")
cat("Working directory:", getwd(), "\n\n")

# Load libraries (in same order as update_scores_weekly.R)
library(arrow)
library(dplyr)
library(readr)
library(stringr)
library(purrr)
library(lubridate)

# Source model_scoring_functions.R (which has here::i_am())
cat("--- Sourcing model_scoring_functions.R ---\n")
source("model_scoring_functions.R")
cat("After sourcing, here::here() returns:", here::here(), "\n\n")

# Source update_scores_weekly.R
cat("--- Sourcing update_scores_weekly.R ---\n")
source("update_scores_weekly.R")

# Get hub_path like the script does
hub_path <- here::here()
cat("hub_path:", hub_path, "\n\n")

# Test date calculations (simulate today = 2026-03-19)
cat("--- Date Calculations ---\n")
today <- as.Date("2026-03-19")
lookback_days <- 7
min_age_days <- 90
oldest_date <- today - min_age_days - lookback_days
newest_date <- today - min_age_days
cat("Today:", as.character(today), "\n")
cat("Date range:", as.character(oldest_date), "to", as.character(newest_date), "\n\n")

# Find all model output files
cat("--- Finding Model Output Files ---\n")
model_output_dir <- file.path(hub_path, "model-output")
cat("model_output_dir:", model_output_dir, "\n")
cat("Directory exists:", dir.exists(model_output_dir), "\n")

all_files <- list.files(
  path = model_output_dir,
  pattern = "\\.parquet$",
  recursive = TRUE,
  full.names = TRUE
)
cat("Total files found:", length(all_files), "\n\n")

# Extract dates
cat("--- Extracting Dates ---\n")
file_dates <- str_extract(all_files, "\\d{4}-\\d{2}-\\d{2}") %>%
  na.omit() %>%
  as.character() %>%
  unique() %>%
  as.Date()
cat("Unique dates found:", length(file_dates), "\n")
cat("Sample dates:", paste(head(file_dates, 10), collapse=", "), "\n\n")

# Filter to date range
cat("--- Filtering to Scoreable Range ---\n")
scoreable_dates <- file_dates[file_dates >= oldest_date & file_dates <= newest_date]
cat("Dates in range:", paste(scoreable_dates, collapse=", "), "\n")
cat("Count:", length(scoreable_dates), "\n\n")

# Check each date for required files
cat("--- Checking Required Files ---\n")
if (length(scoreable_dates) > 0) {
  for (date in scoreable_dates) {
    date_str <- as.character(date)
    cat("\nChecking date:", date_str, "\n")

    # Check oracle
    oracle_path <- file.path(
      hub_path, "target-data", "oracle-output",
      paste0("nowcast_date=", date_str), "oracle.parquet"
    )
    oracle_exists <- file.exists(oracle_path)
    cat("  Oracle path:", oracle_path, "\n")
    cat("  Oracle exists:", oracle_exists, "\n")

    # Check unscored
    unscored_path <- file.path(
      hub_path, "auxiliary-data", "unscored-location-dates",
      paste0(date_str, ".csv")
    )
    unscored_exists <- file.exists(unscored_path)
    cat("  Unscored path:", unscored_path, "\n")
    cat("  Unscored exists:", unscored_exists, "\n")

    # Check if already scored
    scores_path <- file.path(hub_path, "auxiliary-data", "scores", "scores.tsv")
    if (file.exists(scores_path)) {
      scores <- read_tsv(scores_path, show_col_types = FALSE)
      already_scored <- any(scores$nowcast_date == date_str, na.rm = TRUE)
      cat("  Already scored:", already_scored, "\n")
      if (already_scored) {
        scored_count <- sum(scores$nowcast_date == date_str, na.rm = TRUE)
        cat("  Number of existing score rows:", scored_count, "\n")
      }
    } else {
      cat("  scores.tsv not found\n")
    }

    cat("  VERDICT:", oracle_exists && unscored_exists, "\n")
  }
} else {
  cat("No dates found in scoreable range!\n")
}

cat("\n===== TEST COMPLETE =====\n")
