location_sum_one <- function(tbl, file_path) {
  # Here you can write your custom check logic
  # Assign the result as `TRUE` or `FALSE` to object called `check`.
  # If `check` is `TRUE`, the check will pass.

  tbl <- tbl[tbl[["output_type"]] == "sample", ]
  error_object <- check_sum_one(tbl)
  check <- is.null(error_object)

  if (check) {
    details <- NULL
    error_object <- NULL
  } else {
    details <- cli::format_inline("See {.var error_object} attribute for details.")
  }

  hubValidations::capture_check_cnd(
    check = check,
    error = FALSE,
    file_path = file_path,
    msg_subject = "Values in {.var value} column",
    msg_verbs = c("do", "do not")
    msg_attribute = "sum to 1 for each unique modeling task.",
    error_object = error_object,
    details = details
  )
}

# modified from hubValidations:::check_values_sum1
check_sum_one <- function (tbl) {
  tbl[["value"]] <- as.numeric(tbl[["value"]])
  group_cols <- names(tbl)[!names(tbl) %in% hubUtils::std_colnames]
  check_tbl <- tbl %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::arrange("output_type_id", .by_group = TRUE) %>% 
    dplyr::summarise(sum1 = isTRUE(all.equal(sum(.data[["value"]]), 1)))
  if (all(check_tbl$sum1)) {
      return(NULL)
  }
  dplyr::filter(check_tbl, !.data[["sum1"]]) %>% 
    dplyr::select(-dplyr::all_of("sum1")) %>% 
    dplyr::ungroup() %>% 
    dplyr::mutate(output_type = "sample")
}
