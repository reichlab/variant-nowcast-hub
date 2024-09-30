clade_prop_sum_one <- function(tbl, file_path) {
  # 

  tbl <- tbl[tbl[["output_type"]] == "sample", ]
  error_object <- check_sum_one(tbl)
  check <- is.null(error_object)

  if (check) {
    details <- NULL
    error_object <- NULL
  } else {
    # TODO: add information about object details
    details <- cli::format_inline("See {.var error_object} attribute for details")
  }

  hubValidations::capture_check_cnd(
    check = check,
    error = FALSE,
    file_path = file_path,
    msg_subject = "Clade proportions in {.var value} columns",
    msg_verbs = c("do", "do not"),
    msg_attribute = "sum to 1 for each unique modeling task.",
    error_object = error_object,
    details = details
  )
}

cheap_kable <- function(tbl) {
  n <- nrow(tbl)
  cols <- names(tbl)
  pads <- vapply(tbl, nchar, integer(n)) |>
    apply(MARGIN = 2, max)
  cpad <- nchar(cols)
  pad <- ifelse(pads > cpad, pads, cpad)
  tx <- lapply(seq_along(pad), function(i) format(tbl[[i]], width = pad[i]))
  tx <- do.call("paste", c(list(sep = " | "), tx))
  sep <- paste(strrep("-", pad), collapse = " | ")
  hd <- lapply(seq_along(pad), function(i) format(cols[i], width = pad[i]))
  hd <- paste(hd, collapse = " | ")
  c(hd, sep, tx)
}

# modified from hubValidations:::check_values_sum1
check_sum_one <- function (tbl) {
  # remove the clade column as we will not be using it
  tbl[["clade"]] <- NULL
  tbl[["value"]] <- as.numeric(tbl[["value"]])
  # set the group columns to include the modelling targets and the
  # output_type_id, which is the sample ID
  group_cols <- names(tbl)[!names(tbl) %in% hubUtils::std_colnames]
  group_cols <- c(group_cols, "output_type_id")
  check_tbl <- tbl %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarise(sum1 = isTRUE(all.equal(sum(.data[["value"]]), 1)))
  if (all(check_tbl$sum1)) {
    return(NULL)
  }
  # If we get here, then return the task IDs that did not succeed
  dplyr::filter(check_tbl, !.data[["sum1"]]) %>% 
    dplyr::select(-dplyr::all_of("sum1")) %>% 
    dplyr::ungroup() %>% 
    dplyr::mutate(output_type = "sample")
}

