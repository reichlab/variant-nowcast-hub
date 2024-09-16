## create config file output for a round

library(hubAdmin)
library(tools)


get_clade_file_info <- function(directory = "auxiliary-data/modeled-clades") {
  # the round_id is the date of the most recent "clades to model"
  # file in auxiliary-data/modeled-clades
  clades_file_list <- sort(list.files(path = directory, full.names = TRUE), decreasing = TRUE)
  latest_clades_file <- clades_file_list[1]
  clade_file_info <- list(clade_file = latest_clades_file, round_id = file_path_sans_ext(basename(latest_clades_file)))
  return(clade_file_info)
}


get_clade_list <- function(filename) {
  # get a list of the clades to be modeled in this round
  clade_list <- readLines(filename)
  return(clade_list)
}


this_round_clade_file <- get_clade_file_info()
this_round_clade_list <- sort(get_clade_list(this_round_clade_file$clade_file))
this_round_date <- this_round_clade_file$round_id
if (isFALSE(weekdays(as.Date(this_round_date)) == "Wednesday")) {
  stop("The latest clade_file does not have a Wednesday date: ", this_round_clade_file)
}


model_tasks <- hubAdmin::create_model_tasks(
  hubAdmin::create_model_task(
    task_ids = create_task_ids(
      hubAdmin::create_task_id("nowcast_date",
        required = list(this_round_date),
        optional = NULL
      ),
      hubAdmin::create_task_id("target_date",
        required = NULL,
        ## target date is nowcast_date and the three prior weeks
        optional = as.character(as.Date(this_round_date) - c(0, 7, 14, 21))
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
      hubAdmin::create_task_id("variant",
        required = this_round_clade_list,
        optional = NULL
      )
    ),
    output_type = hubAdmin::create_output_type(
      hubAdmin::create_output_type_sample(
        is_required = FALSE,
        output_type_id_type = "character",
        max_length = 15L,
        min_samples_per_task = 1L,
        max_samples_per_task = 500L,
        value_type = "double",
        value_minimum = 0L,
        value_maximum = 1L,
      )
    ),
    target_metadata = hubAdmin::create_target_metadata(
      hubAdmin::create_target_metadata_item(
        target_id = "variant prop",
        target_name = "Weekly nowcasted variant proportions",
        target_units = "proportion",
        target_keys = NULL,
        target_type = "compositional",
        is_step_ahead = TRUE,
        time_unit = "week"
      )
    )
  )
)


new_round <- hubAdmin::create_rounds(
  create_round(
    "nowcast_date",
    round_id_from_variable = TRUE,
    model_tasks = model_tasks,
    submissions_due = list(
      relative_to = "nowcast_date",
      start = -7L,
      end = 1L
    )
  )
)


task_config <- hubAdmin::create_config(new_round)
hubAdmin::write_config(task_config, overwrite = TRUE, silent = TRUE)


valid_task_config <- validate_config(
  hub_path = ".",
  config = c("tasks"),
  schema_version = "from_config",
  branch = "main"
)
if (isFALSE(valid_task_config)) {
  print(valid_task_config)
  stop("Generated task config is invalid for round: ", this_round_date)
}

# TODO: create a sample model-output file for this round
# https://hubverse-org.github.io/hubData/reference/create_model_out_submit_tmpl.html
# create_config function?


# TODO: create a sample model-output file for this round
# https://hubverse-org.github.io/hubData/reference/create_model_out_submit_tmpl.html
