clade_prop_sum_one <- function(tbl, file_path) {
  tbl <- tbl[tbl[["output_type"]] %in% c("mean", "sample"), ]
  error_object <- check_sum_one(tbl)
  check <- is.null(error_object)

  if (check) {
    details <- NULL
    error_object <- NULL
  } else {
    n <- nrow(error_object)
    bad_msg <- c(
      "\fThere {?was/were} {.strong {.val {n}} task{?s} with values that did not sum to one}:",
      if (n > 10) "\f{.emph (showing first 10 rows)}",
      cheap_kable(head(error_object, 10))
    )
    # Wrapping 
    # https://cli.r-lib.org/reference/inline-markup.html#wrapping
    details <- cli::format_inline(paste(bad_msg, collapse = "\f"))
  }

  hubValidations::capture_check_cnd(
    check = check,
    error = FALSE,
    file_path = file_path,
    msg_subject = "All clade proportions in {.var value} columns",
    msg_verbs = c("", "do not"),
    msg_attribute = "{.emph sum to one} for each unique modeling task.",
    error_object = error_object,
    details = details
  )
}


ALL_ONE <- function(dat) isTRUE(all.equal(sum(dat), 1, tolerance = 1e-3))

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
    dplyr::summarise(sum1 = ALL_ONE(.data[["value"]]), .groups = "drop")
  if (all(check_tbl$sum1)) {
    return(NULL)
  }
  # If we get here, then return the task IDs that did not succeed
  baddies <- dplyr::filter(check_tbl, !.data[["sum1"]]) %>% 
    dplyr::select(-dplyr::all_of("sum1")) %>% 
    dplyr::ungroup()
  baddies$output_type <- ifelse(is.na(baddies$output_type_id), "mean", "sample")
  return(baddies)
}

## PRINTING UTILITIES ----------------------------------------------------------

cheap_kable <- function(tbl) {
  n <- nrow(tbl)
  cols <- names(tbl)
  pads <- vapply(tbl, nchar, integer(n), allowNA = TRUE, keepNA = FALSE)
  if (n > 1) {
    pads <- apply(pads, MARGIN = 2, max, na.rm = TRUE)
  }
  cpad <- nchar(cols)
  pad <- ifelse(pads > cpad, pads, cpad)
  tx <- lapply(seq_along(pad), function(i) format(tbl[[i]], width = pad[i]))
  tx <- sprintf("| %s |", do.call("paste", c(list(sep = " | "), tx)))
  hd <- lapply(seq_along(pad), function(i) format(cols[i], width = pad[i]))
  hd <- make_table_like(hd)
  sep <- make_table_like(strrep("-", pad))
  # This doesn't really work at the moment -_-)
  # https://cli.r-lib.org/articles/semantic-cli.html?q=non-breaking#non-breaking-spaces
  gsub("\\s", "\u00a0", c(hd, sep, tx))
}

make_table_like <- function(vec) {
  sprintf("| %s |", paste(vec, collapse = " | "))
}

## TESTS -----------------------------------------------------------------------

test <- function() {
  good_tbl <- example_tbl()
  okay_tbl <- good_tbl
  okay_tbl$value[30] <- okay_tbl$value[30] + 9e-4
  bad_tbl <- example_tbl(make_it_bad = TRUE)

  # basic error tests
  stopifnot(
    "good data has an error" = is.null(check_sum_one(good_tbl)),
    "data within tolerance has an error" = is.null(check_sum_one(okay_tbl)),
    "bad data does not error" = is.data.frame(check_sum_one(bad_tbl)),
    "bad data has wrong number of errors" = nrow(check_sum_one(bad_tbl)) == 2,
    "main validation returns incorrect class" = inherits(clade_prop_sum_one(good_tbl, "test"), "check_success"),
    "main validation returns incorrect class" = inherits(clade_prop_sum_one(bad_tbl, "test"), "check_failure"),
    "main validation does not return table" = is.data.frame(clade_prop_sum_one(bad_tbl, "test")$error_object),
    "main validation does not correct number of rows" = nrow(clade_prop_sum_one(bad_tbl, "test")$error_object) == 2,
    TRUE
  )

  # value tests
  A <- B <- C <- good_tbl
  A$location <- "A"
  B$location <- "B"
  C$location <- "C"
  big_bad <- dplyr::bind_rows(A, B, C)
  big_bad$value <- big_bad$value + 0.5
  # tests for the objects
  good_res <- clade_prop_sum_one(good_tbl, "test")
  bad_res <- clade_prop_sum_one(bad_tbl, "test")
  big_bad_res <- clade_prop_sum_one(big_bad, "test")

  # capture the results of the print method
  good_out <- capture.output(good_res)
  bad_out <- capture.output(bad_res)
  big_bad_out <- capture.output(big_bad_res)
  expect_rows <- function(output, n) {
    if (n > 0) {
      n <- n + 2 # account for header
    }
    sum(grepl("^[|]", output)) == n
  }
  stopifnot(
    "good output has non-null error object" = is.null(good_res$error_object),
    "output table is shown for good data" = expect_rows(good_out, 0),
    "bad output table has wrong number of rows" = expect_rows(bad_out, 2),
    "bad output error object has unexpected rows" = nrow(bad_res$error_object) == 2,
    "big bad output table has wrong number of rows" = expect_rows(big_bad_out, 10),
    "big bad output error object has unexpected rows" = nrow(big_bad_res$error_object) == 12 + 6,
    TRUE
  )
  
}

example_tbl <- function(make_it_bad = FALSE) {
  # generated from the README of the model output folder
  to_generate <- r"{
    res <- rvest::read_html("https://github.com/reichlab/variant-nowcast-hub/blob/main/model-output/README.md") |>
      rvest::html_table()
    out <- dplyr::bind_rows(res[2:3])
    datapasta::df_paste(out)
  }"
  # uncomment this part to generate new data and then paste it below
  # eval(parse(text = to_generate))
  out <- data.frame(
    stringsAsFactors = FALSE,
        nowcast_date = c("2024-09-25","2024-09-25",
                         "2024-09-25","2024-09-25","2024-09-25","2024-09-25",
                         "2024-09-25","2024-09-25","2024-09-25","2024-09-25",
                         "2024-09-25","2024-09-25","2024-09-25","2024-09-25",
                         "2024-09-25","2024-09-25","2024-09-25","2024-09-25",
                         "2024-09-25","2024-09-25","2024-09-25","2024-09-25",
                         "2024-09-25","2024-09-25","2024-09-25","2024-09-25",
                         "2024-09-25","2024-09-25","2024-09-25","2024-09-25"),
         target_date = c("2024-09-23","2024-09-23",
                         "2024-09-23","2024-09-23","2024-09-23","2024-09-24",
                         "2024-09-24","2024-09-24","2024-09-24","2024-09-24",
                         "2024-09-23","2024-09-23","2024-09-23","2024-09-23",
                         "2024-09-23","2024-09-24","2024-09-24","2024-09-24",
                         "2024-09-24","2024-09-24","2024-09-23","2024-09-23",
                         "2024-09-23","2024-09-23","2024-09-23","2024-09-24",
                         "2024-09-24","2024-09-24","2024-09-24","2024-09-24"),
            location = c("MA","MA","MA","MA","MA",
                         "MA","MA","MA","MA","MA","MA","MA","MA","MA","MA",
                         "MA","MA","MA","MA","MA","MA","MA","MA","MA",
                         "MA","MA","MA","MA","MA","MA"),
               clade = c("24A","24B","24C",
                         "recombinant","other","24A","24B","24C","recombinant"
  ,"other",
                         "24A","24B","24C","recombinant","other","24A",
                         "24B","24C","recombinant","other","24A","24B","24C",
                         "recombinant","other","24A","24B","24C","recombinant"
  ,
                         "other"),
         output_type = c("mean","mean","mean","mean",
                         "mean","mean","mean","mean","mean","mean","sample",
                         "sample","sample","sample","sample","sample",
                         "sample","sample","sample","sample","sample","sample"
  ,
                         "sample","sample","sample","sample","sample","sample"
  ,
                         "sample","sample"),
      output_type_id = c(NA,NA,NA,NA,NA,NA,NA,NA,
                         NA,NA,"MA00","MA00","MA00","MA00","MA00","MA00",
                         "MA00","MA00","MA00","MA00","MA01","MA01","MA01",
                         "MA01","MA01","MA01","MA01","MA01","MA01","MA01"),
               value = c(0.1,0.2,0.05,0.6,0.05,0.12,
                         0.18,0.02,0.6,0.08,0.1,0.2,0.05,0.6,0.05,0.12,
                         0.18,0.02,0.6,0.08,0.1,0.2,0.05,0.6,0.05,0.12,
                         0.18,0.02,0.6,0.08)
  )
  if (make_it_bad) {
    n <- nrow(out)
    out$value[c(n, n - 5)] <- 0.5
  }
  return(out)
}
