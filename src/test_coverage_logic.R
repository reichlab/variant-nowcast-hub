# Comprehensive test of coverage automation logic
# This simulates exactly what happens in GitHub Actions

# Set working directory to src/ (like GitHub Actions does)
setwd("src")
cat("===== COMPREHENSIVE COVERAGE TEST =====\n")
cat("Working directory:", getwd(), "\n\n")

# Load libraries (in same order as update_coverage_weekly.R)
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

# Source update_coverage_weekly.R
cat("--- Sourcing update_coverage_weekly.R ---\n")
source("update_coverage_weekly.R")

# Get hub_path like the script does
hub_path <- here::here()
cat("hub_path:", hub_path, "\n\n")

# Test 1: Check file paths
cat("--- Test 1: File Path Resolution ---\n")
scores_path <- file.path(hub_path, "auxiliary-data", "scores", "scores.tsv")
coverage_path <- file.path(hub_path, "auxiliary-data", "scores", "coverage.parquet")
cat("scores.tsv path:", scores_path, "\n")
cat("scores.tsv exists:", file.exists(scores_path), "\n")
cat("coverage.parquet path:", coverage_path, "\n")
cat("coverage.parquet exists:", file.exists(coverage_path), "\n\n")

# Test 2: Identify missing coverage
cat("--- Test 2: Identify Missing Coverage ---\n")
missing_dates <- identify_missing_coverage(hub_path)
cat("\nMissing coverage for", length(missing_dates), "nowcast dates:\n")
if (length(missing_dates) > 0) {
  cat("  ", paste(missing_dates, collapse = ", "), "\n")
}
cat("\n")

# Test 3: Check date handling in loops
cat("--- Test 3: Date Handling Test ---\n")
if (length(missing_dates) > 0) {
  test_dates <- head(missing_dates, 2)
  cat("Test dates:", paste(test_dates, collapse = ", "), "\n")

  cat("\nOLD METHOD (broken):\n")
  for (date in as.Date(test_dates)) {
    date_str <- as.character(date)
    cat("  date_str:", date_str, "(type:", class(date), ")\n")
  }

  cat("\nNEW METHOD (fixed):\n")
  for (date_str in as.character(test_dates)) {
    cat("  date_str:", date_str, "(type: character)\n")
  }
}
cat("\n")

# Test 4: Check model files exist for a test date
cat("--- Test 4: Model Files Check ---\n")
if (length(missing_dates) > 0) {
  test_date <- missing_dates[1]
  cat("Checking model files for:", test_date, "\n")

  model_files <- list.files(
    path = file.path(hub_path, "model-output"),
    pattern = paste0(test_date, ".*\\.parquet$"),
    recursive = TRUE,
    full.names = TRUE
  )

  cat("Found", length(model_files), "model submission(s)\n")
  if (length(model_files) > 0) {
    cat("Sample files:\n")
    for (f in head(model_files, 3)) {
      cat("  ", basename(dirname(f)), "/", basename(f), "\n", sep = "")
    }
  }
}
cat("\n")

# Test 5: Type compatibility check
cat("--- Test 5: Type Compatibility Test ---\n")
if (file.exists(coverage_path)) {
  existing_coverage <- read_parquet(coverage_path)
  cat("Existing coverage column types:\n")
  cat("  nowcast_date:", class(existing_coverage$nowcast_date), "\n")
  cat("  target_date:", class(existing_coverage$target_date), "\n")

  # Simulate new coverage with correct types
  new_coverage <- tibble(
    model_id = "test",
    nowcast_date = as.Date("2025-12-17"),
    target_date = as.Date("2025-12-01"),
    location = "CA",
    clade = "24A",
    quantile_level = 0.5,
    interval_range = 0,
    interval_coverage = 1,
    quantile_coverage = 1,
    quantile_coverage_deviation = 0.5,
    scored = TRUE,
    status = NA_character_
  )

  cat("\nNew coverage column types:\n")
  cat("  nowcast_date:", class(new_coverage$nowcast_date), "\n")
  cat("  target_date:", class(new_coverage$target_date), "\n")

  # Try to bind
  tryCatch({
    test_bind <- bind_rows(existing_coverage, new_coverage)
    cat("\n✓ bind_rows() succeeded! Combined", nrow(test_bind), "rows\n")
  }, error = function(e) {
    cat("\n✗ bind_rows() failed:", e$message, "\n")
  })
}
cat("\n")

cat("===== TEST COMPLETE =====\n")
cat("\nNext step: Run update_weekly_coverage() to test full automation\n")
