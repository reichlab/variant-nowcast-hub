## Add a new round to the hub's task config (hub-config/tasks.json)
## This script is part of a "round open" process run via a scheduled GitHub action and
## should be run from the hub's src/ directory.
##
## The script will create a new round and add it to the hub's existing task config (tasks.json).
## If tasks.json does not exist, the script will create one and add the new round.
## In this hub, each round uses a different list of clades to model, and that information is
## stored in auxiliary-data/modeled-clades. This directory contains a file for each round, so
## the code below finds the most recent file in it and uses the filename to determine the round_id.

here::i_am("src/make_round_config.R")
library(cli)
library(here)
library(hubAdmin)
library(hubUtils)
library(jsonlite)
library(lobstr)
library(tools)


#' Get the hub's latest clade file
#'
#' @description
#' `get_latest_clade_file` finds the hub's most recent "list of clades to
#' model" and returns its filename and the round_id derived from the filename.
#'
#' @param hub_dir Character vector. The full path the the hub's root directory.
#' @returns A list with two elements: `clade_file` is the full path to the hub's
#'   latest clade file, and `round_id` is the round_id of the modeling round
#'   that will predict the clades in `clade_file`.
get_latest_clade_file <- function(hub_dir) {
  directory <- file.path(hub_dir, "auxiliary-data", "modeled-clades")
  clades_file_list <- sort(list.files(path = directory, full.names = TRUE), decreasing = TRUE)
  latest_clades_file <- clades_file_list[1]
  clade_file_info <- list(clade_file = latest_clades_file, round_id = file_path_sans_ext(basename(latest_clades_file)))
  return(clade_file_info)
}


#' Create a new round object
#'
#' @description
#' `create_new_round` creates a new Hubverse round object based on the hub's
#' most recently-created list of clades to model.
#'
#' @param hub_root Character vector. The full path to the hub's root directory.
#' @returns A round object.
create_new_round <- function(hub_root) {
  the_schema <- "v3.0.1"
  this_round_clade_file <- get_latest_clade_file(hub_root)
  this_round_clade_list <- fromJSON(this_round_clade_file$clade_file)$clades
  this_round_date <- this_round_clade_file$round_id
  if (isFALSE(weekdays(as.Date(this_round_date)) == "Wednesday")) {
    stop("The latest clade_file does not have a Wednesday date: ", this_round_clade_file)
  }

  model_tasks <- hubAdmin::create_model_tasks(
    hubAdmin::create_model_task(
      task_ids = hubAdmin::create_task_ids(
        hubAdmin::create_task_id("nowcast_date",
          schema = the_schema,
          required = list(this_round_date),
          optional = NULL
        ),
        hubAdmin::create_task_id("target_date",
          schema = the_schema,
          required = NULL,
          ## target date is nowcast_date and the three prior weeks
          optional = as.character(seq(as.Date(this_round_date) - 31, as.Date(this_round_date) + 10, by = "day"))
        ),
        hubAdmin::create_task_id("location",
          schema = the_schema,
          required = NULL,
          optional = c(
            "AL", "AK", "AZ", "AR", "CA", "CO",
            "CT", "DE", "DC", "FL", "GA", "HI",
            "ID", "IL", "IN", "IA", "KS", "KY",
            "LA", "ME", "MD", "MA", "MI", "MN",
            "MS", "MO", "MT", "NE", "NV", "NH",
            "NJ", "NM", "NY", "NC", "ND", "OH",
            "OK", "OR", "PA", "RI", "SC", "SD",
            "TN", "TX", "UT", "VT", "VA", "WA",
            "WV", "WI", "WY", "PR"
          )
        ),
        hubAdmin::create_task_id("clade",
          schema = the_schema,
          required = this_round_clade_list,
          optional = NULL
        )
      ),
      output_type = hubAdmin::create_output_type(
        hubAdmin::create_output_type_mean(
          schema = the_schema,
          is_required = FALSE,
          value_type = "double",
          value_minimum = 0L,
          value_maximum = 1L
        ),
        hubAdmin::create_output_type_sample(
          schema = the_schema,
          is_required = FALSE,
          output_type_id_type = "character",
          max_length = 15L,
          min_samples_per_task = 100L,
          max_samples_per_task = 100L,
          compound_taskid_set = c("nowcast_date", "location"),
          value_type = "double",
          value_minimum = 0L,
          value_maximum = 1L,
        )
      ),
      target_metadata = hubAdmin::create_target_metadata(
        hubAdmin::create_target_metadata_item(
          schema = the_schema,
          target_id = "clade prop",
          target_name = "Daily nowcasted clade proportions",
          target_units = "proportion",
          target_keys = NULL,
          target_type = "compositional",
          is_step_ahead = TRUE,
          time_unit = "day"
        )
      )
    )
  )

  round <- hubAdmin::create_round(
    "nowcast_date",
    round_id_from_variable = TRUE,
    model_tasks = model_tasks,
    submissions_due = list(
      relative_to = "nowcast_date",
      start = -2L,
      end = 1L
    )
  )
  return(round)
}

#' Write and validate task config
#'
#' @description
#' `write_and_validate_task_config` writes a task config to the hub (tasks.json)
#' and validates it, returning an error if the config is invalid.
write_and_validate_task_config <- function(task_config, round_id, hub_root) {
  hubAdmin::write_config(task_config, hub_path = hub_root, overwrite = TRUE, silent = TRUE)
  valid_task_config <- hubAdmin::validate_config(
    hub_path = hub_root,
    config = c("tasks"),
    schema_version = "from_config",
    branch = "main"
  )
  if (isFALSE(valid_task_config)) {
    cli::cli_alert_danger("Generated task config (tasks.json) is invalid")
    cli::cli_h1("Invalid task config")
    lobstr::tree(task_config)
    stop()
  }
}


hub_root <- here::here()
new_round <- create_new_round(hub_root)

existing_task_config <- try(hubUtils::read_config(hub_root, config = c("tasks")), silent = TRUE)
if (inherits(existing_task_config, "try-error")) {
  cli::cli_alert_info("Existing config not found, creating a new {.file tasks.json}")
  new_task_config <- hubAdmin::create_config(hubAdmin::create_rounds(new_round))
} else {
  cli::cli_alert_info("Existing config found, adding a new round")
  new_task_config <- hubAdmin::append_round(existing_task_config, new_round)
}

write_and_validate_task_config(new_task_config, this_round_date, hub_root)
cli::cli_h1("New round added to {.file tasks.json}")
lobstr::tree(new_round)
