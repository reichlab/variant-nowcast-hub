## script to make a PDF to plot clades for one location
library(arrow)
library(dplyr)

#source("../variant-nowcast-hub/src/plot_one_location_clades.R")
source("./src/plot_one_location_clades.R")
#source("~/Downloads/2024-10-30-UMass-HMLR.parquet")
#dat <- read_parquet("../variant-nowcast-hub/model-output/UMass-HMLR/2024-10-09-UMass-HMLR.parquet")
dat <- read_parquet("./model-output/UMass-HMLR/2024-11-06-UMass-HMLR.parquet")

## load in the hub locations file
#load("../covidHubUtils/data/hub_locations.rda")
load("./src/hub_locations.rda")
locs <- hub_locations |>
  dplyr::select(abbreviation, location_name)

## read in and process target data file
targets <- read_parquet("https://covid-clade-counts.s3.amazonaws.com/2024-11-04_covid_clade_counts.parquet")
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
ggsave("~/Downloads/test_weekly_2024-11-06.pdf",
       gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
       width = 12,
       height = 8)

## Daily plots
plots <- lapply(unique(dat$location), function(.x)
  plot_one_location_clades(this_location = .x,
                           model_output_data = dat,
                           target_data = targets_other_wk))
ggsave("~/Downloads/test_daily_2024-11-06.pdf",
       gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
       width = 12,
       height = 8)

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
ggsave("~/Downloads/test_logit_weekly_2024-11-06.pdf",
       gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
       width = 12,
       height = 8)

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
ggsave("~/Downloads/test_logits_daily_2024-11-06.pdf",
       gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
       width = 12,
       height = 8)


#plot_one_location_clades(this_location="TX", model_outpu