## create config file output for a round

library(hubUtils)

this_round_date <-  "2023-01-05"  ## for all rounds, should be the same day of week

model_tasks <- create_model_tasks(
  create_model_task(
    task_ids = create_task_ids(
      create_task_id("nowcast_date",
                     required = this_round_date,
                     optional = NULL
      ),
      create_task_id("target_date",
                     required = NULL,
                     ## making this to be nowcast_date and the three prior weeks
                     optional = as.character(as.Date(this_round_date) - c(0, 7, 14, 21))
      ),
      create_task_id("location",
                     required = NULL,
                     optional = c("US",
                                  "01", "02", "04", "05", "06", "08", "09",
                                  "10", "11", "12", "13", "15", "16", "17", "18", "19",
                                  "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
                                  "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
                                  "40", "41", "42", "44", "45", "46", "47", "48", "49",
                                  "50", "51", "53", "54", "55", "56", "60", "66", "69",
                                  "72", "74", "78")
      ),
      create_task_id("variant",
                     ## noting that we could specify them as optional and then infer 0s if missing
                     required = c("XBB.1"), ## some character strings of variant names,
                     optional = NULL
      )
    ),
    output_type = create_output_type(
      create_output_type_sample(
        required = 1:500,
        optional = NULL,
        value_type = "double",
        ## the following lines throw an error currently
        # value_minimum = 0L,
        # value_maximum = 1L
      )
    ),
    target_metadata = create_target_metadata(
      create_target_metadata_item(
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

create_round(
  round_id = "nowcast_date",
  round_id_from_variable = TRUE,
  model_tasks = model_tasks,
  submissions_due = list(
    relative_to = "nowcast_date",
    start = -7L,
    end = 1L
  ),
  last_data_date = "2023-01-06"
)
