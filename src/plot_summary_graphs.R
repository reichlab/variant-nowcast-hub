
plot_summary_graphs <- function(model_output_file = NULL, s3_data_date = "2024-11-04", save_path = "~/Downloads/"){
  ## function to make PDF graphics to plot clades by location for daily and weekly
  ## observed and predicted counts in addition to logit scale based on model-output file
  # model_output_file = character string, directory under variant-nowcast-hub/[team name]/[model output parquet file]
  # s3_data_date = character string, the date to pull data from S3 bucket
  # ...
  
  library(arrow)
  library(dplyr)
  
  # Source plot_one_locatino_clades.R functions
  source("./src/plot_one_location_clades.R")
  
  # Model output data from model_output
  dat_path <- paste("./model-output/", model_output_file, sep = "")
  dat <- read_parquet(dat_path)
  
  ## load in the hub locations file
  #load("../covidHubUtils/data/hub_locations.rda")
  load("./src/hub_locations.rda")
  locs <- hub_locations |>
    dplyr::select(abbreviation, location_name)
  
  ## read in and process target data file
  targets_path_s3 <- paste("https://covid-clade-counts.s3.amazonaws.com/", 
                           s3_data_date, "_covid_clade_counts.parquet", sep = "")
  targets <- read_parquet(targets_path_s3)
  clades <- unique(dat$clade)
  
  targets_other <- targets |>
    filter(!is.na(date), date >= "2024-01-01") |>
    mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
    tidyr::complete(location, date, clade, fill = list(count=0)) |>
    group_by(location, date) |>
    mutate(total = sum(count)) |>
    ungroup() |>
    mutate(value = ifelse(total == 0, 0, count/total)) |>
    #left_join(locs, by = c("location" = "location_name")) |>
    #select(abbreviation, date, clade, count, total, value) |>
    #rename(location = abbreviation) |>
    mutate(type = "target")
  
  targets_other_wk <- targets_other |>
    mutate(wday = lubridate::wday(date),
           epiweek_end = date + 7 - wday) |>
    group_by(location, clade, epiweek_end) |>
    summarize(count = sum(count)) |>
    ungroup() |>
    group_by(location, epiweek_end) |>
    mutate(total = sum(count)) |>
    ungroup() |>
    mutate(value = ifelse(total == 0, 0, count/total)) |>
    rename(date = epiweek_end) |>
    arrange(location, date, clade)
  
  # smoothed_targets_wk <- targets_other_wk
  # for (location in unique(targets_other_wk$location)) {
  #   for (clade in unique(targets_other_wk$clade)) {
  #     sub <- targets_other_wk[targets_other_wk$location == "NY" & targets_other_wk$clade == "24A", ]
  #   }
  # }
  
  # Weekly plots
  plots <- lapply(unique(dat$location), function(.x)
    plot_one_location_clades(this_location = .x,
                             model_output_data = dat,
                             target_data = targets_other_wk))
  
  save_path_local = paste(save_path, "test_weekly_", s3_data_date, ".pdf", sep = "")
  ggsave(save_path_local,
         gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
         width = 12,
         height = 8)
  rm(save_path_local)
  
  ## Daily plots
  plots <- lapply(unique(dat$location), function(.x)
    plot_one_location_clades(this_location = .x,
                             model_output_data = dat,
                             target_data = targets_other))
  save_path_local = paste(save_path, "test_daily_", s3_data_date, ".pdf", sep = "")
  ggsave(save_path_local,
         gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
         width = 12,
         height = 8)
  rm(save_path_local)
  
  # Select baseline clade
  baseline <- "24A"
  samples <- dat[dat$output_type == "sample", ]
  
  test <- merge(samples, samples[samples$clade == baseline, c("target_date", "output_type_id", "value")], 
                by = c("target_date", "output_type_id"), suffixes = c("", ".base"),
                all.x = TRUE)
  test$logitval <- log(test$value) - log(test$value.base)
  test$value.base <- NULL
  test$value <- test$logitval
  test$logitval <- NULL
  
  targetstest_wk <- merge(targets_other_wk, targets_other_wk[targets_other_wk$clade == baseline, 
                                                             c("date", "location", "value")],
                          by = c("date", "location"), suffixes = c("", ".base"),
                          all.x = TRUE)
  targetstest_wk <- targetstest_wk[targetstest_wk$value > 0 & targetstest_wk$value.base > 0, ]
  targetstest_wk$logitval <- log(targetstest_wk$value) - log(targetstest_wk$value.base)
  targetstest_wk$value.base <- NULL
  targetstest_wk$value <- targetstest_wk$logitval
  targetstest_wk$logitval <- NULL
  
  ## Logit plots
  plots <- lapply(unique(dat$location), function(.x)
    plot_one_location_clades(this_location = .x,
                             model_output_data = test,
                             target_data = targetstest_wk))
  
  save_path_local = paste(save_path, "test_weekly_logit_", s3_data_date, ".pdf", sep = "")
  ggsave(save_path_local,
         gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
         width = 12,
         height = 8)
  rm(save_path_local)
  
  targetstest <- merge(targets_other, targets_other[targets_other$clade == baseline, 
                                                    c("date", "location", "value")],
                       by = c("date", "location"), suffixes = c("", ".base"), all.x = TRUE)
  targetstest <- targetstest[targetstest$value > 0 & targetstest$value.base > 0, ]
  targetstest$logitval <- log(targetstest$value) - log(targetstest$value.base)
  targetstest$value.base <- NULL
  targetstest$value <- targetstest$logitval
  targetstest$logitval <- NULL
  
  ## Logit plots daily
  plots <- lapply(unique(dat$location), function(.x)
    plot_one_location_clades(this_location = .x,
                             model_output_data = test,
                             target_data = targetstest))
  
  save_path_local = paste(save_path, "test_daily_logit_", s3_data_date, ".pdf", sep = "")
  ggsave(save_path_local,
         gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
         width = 12,
         height = 8)
}