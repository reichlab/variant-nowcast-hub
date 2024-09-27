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

#' Return the clades that modelers will predict in the new round
#'
#' @description
#' `get_clade_list` reads the hub's latest clade file and returns a list
#' of the SARS-CoV-2 clades that will be required in the round's clade task_id.
#'
#' @param filename Character vector. Full path to the hub's latest clade file.
#' @returns A list with one element that contains the clades to be modeled.
get_clade_list <- function(filename) {
  clade_list <- readLines(filename)
  return(clade_list)
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
  this_round_clade_file <- get_latest_clade_file(hub_root)
  this_round_clade_list <- sort(get_clade_list(this_round_clade_file$clade_file))
  this_round_date <- this_round_clade_file$round_id
  if (isFALSE(weekdays(as.Date(this_round_date)) == "Wednesday")) {
    stop("The latest clade_file does not have a Wednesday date: ", this_round_clade_file)
  }

  model_tasks <- hubAdmin::create_model_tasks(
    hubAdmin::create_model_task(
      task_ids = hubAdmin::create_task_ids(
        hubAdmin::create_task_id("nowcast_date",
          required = list(this_round_date),
          optional = NULL
        ),
        hubAdmin::create_task_id("target_date",
          required = NULL,
          ## target date is nowcast_date and the three prior weeks
          optional = as.character(seq(as.Date(this_round_date) - 31, as.Date(this_round_date) + 10, by = "day"))
        ),
        hubAdmin::create_task_id("location",
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
          required = this_round_clade_list,
          optional = NULL
        )
      ),
      output_type = hubAdmin::create_output_type(
        hubAdmin::create_output_type_mean(
          is_required = FALSE,
          value_type = "double",
          value_minimum = 0L,
          value_maximum = 1L
        ),
        hubAdmin::create_output_type_sample(
          is_required = FALSE,
          output_type_id_type = "character",
          max_length = 15L,
          min_samples_per_task = 100L,
          max_samples_per_task = 100L,
          value_type = "double",
          value_minimum = 0L,
          value_maximum = 1L,
        )
      ),
      target_metadata = hubAdmin::create_target_metadata(
        hubAdmin::create_target_metadata_item(
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

#' Coerce a list to a round object
#'
#' @description
#' `coerce_to_round` converts a list of round information to a round object,
#'   using attributes of the newly-created round as needed.
#'
#' @param existing_round List. A single hub round, in list form.
#' @param new_round A Hubverse round created via hubAdmin::create_new_round().
#' @returns A Hubverse round.
coerce_to_round <- function(existing_round, new_round) {
  class(existing_round) <- c("round", "list")
  attr(existing_round, "round_id") <- attr(new_round, "round_id")
  attr(existing_round, "schema_id") <- attr(new_round, "schema_id")
  existing_round$model_tasks[[1]]$task_ids[["nowcast_date"]][["required"]] <-
    list(existing_round$model_tasks[[1]]$task_ids[["nowcast_date"]][["required"]])
  return(existing_round)
}

#' Create a new task_config that includes existing rounds and a new round
#'
#' @description
#' `append_to_round` coerces the hub's existing rounds to a list of rounds,
#'   appends the new round to the list, and uses the result to create a new
#'   task config.
#'
#' @param old_task_config List. A hub task config in list form, as created by
#'   hubAdmin::read_config().
#' @param new_round A Hubverse round created via hubAdmin::create_new_round().
#' @returns A Hubverse task config that represents the hub's existing rounds
#'   plus a newly-created round.
append_round <- function(old_task_config, new_round) {
  existing_round_list <- lapply(old_task_config$rounds, coerce_to_round, new_round)
  round_list <- append(existing_round_list, list(new_round))
  tryCatch(
    {
      rounds <- do.call(hubAdmin::create_rounds, round_list)
    },
    error = function(err)
    {
      cli::cli_alert_danger(
        "Error calling hubAdmin::create_rounds (likely because the new round object failed validation)")
        cli::cli_h1("Error")
      print(err)
      stop()
    }
  )
  new_task_config <- hubAdmin::create_config(rounds)
  return(new_task_config)
}

hub_root <- here::here()
new_round <- create_new_round(hub_root)

existing_task_config <- try(hubUtils::read_config(hub_root, config = c("tasks")), silent = TRUE)
if (inherits(existing_task_config, "try-error")) {
  cli::cli_alert_info("Existing config not found, creating a new tasks.json")
  new_task_config <- hubAdmin::create_config(hubAdmin::create_rounds(new_round))
} else {
  cli::cli_alert_info("Existing config found, adding a new round")
  new_task_config <- append_round(existing_task_config, new_round)
}

write_and_validate_task_config(new_task_config, this_round_date, hub_root)
cli::cli_h1("New round added to tasks.json")
cli::cli_alert_success(lobstr::tree(new_round))
