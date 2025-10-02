###
# Script to plot model output (UMass-HMLR default, others manually for now)
# with data available at reference date (training data) and data validated
# through CladeTime 90+ days later for validation purposes.

# Currently does daily plots, but will be extended to weekly
library("dplyr")
library("ggplot2")
library("arrow")
options(dplyr.summarise.inform = FALSE) # Suppress message output for dplyr use
#here::i_am("src/plot_validation_data.R")

# Load validation data from target data dirs
hub_path <- here::here()

# Using newest Hub target data format
df_validation <- arrow::read_parquet(paste0(hub_path, "/target-data/time-series/as_of=2025-03-25/nowcast_date=2024-12-25/timeseries.parquet"))

# Meta data for getting data available on reference date
reference_date <- "2024-12-25" # Date for nowcasting submission
s3_data_date <- as.character(as.Date(reference_date) - 2)
targets_path_s3 <- paste0("https://covid-clade-counts.s3.amazonaws.com/",
                          s3_data_date, "_covid_clade_counts.parquet")
df_retro <- arrow::read_parquet(targets_path_s3)

# Model output file, just UMass for now
df_model_output <- arrow::read_parquet(file.path(hub_path, "model-output/UMass-HMLR/2024-12-25-UMass-HMLR.parquet"))
df_model_output_2 <- arrow::read_parquet(file.path(hub_path, "model-output/UGA-multicast/2024-12-25-UGA-multicast.parquet"))
df_model_output_base <- arrow::read_parquet(file.path(hub_path, "model-output/Hub-baseline/2024-12-25-Hub-baseline.parquet"))

clades <- unique(df_model_output$clade)

targets_retro <- df_retro |>
  filter(!is.na(date), date >= (as.Date(s3_data_date) - 150)) |>
  mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
  group_by(location, date, clade) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop") |>
  tidyr::complete(location, date, clade, fill = list(count=0)) |>
  group_by(location, date) |>
  mutate(total = sum(count)) |>
  ungroup() |>
  mutate(value = ifelse(total == 0, 0, count/total)) |>
  mutate(type = "target")

# Create a PDF file to save the plots
# Make argument to function eventually
save_path = paste0(hub_path, "/plot_validation_by_location_", reference_date, ".pdf")
pdf(save_path)
unique_locs <- sort(unique(df_model_output$location))

# string for printing purposes
date_obs <- paste0("Available Data ", reference_date)

for (this_location in unique_locs){

  targets_retro_this_location <- targets_retro |> subset((location == this_location))

  targets <- df_validation |>
    mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
    group_by(location, target_date, clade) |>
    summarise(observation = sum(observation, na.rm = TRUE), .groups = "drop") |>
    tidyr::complete(location, target_date, clade, fill = list(observation = 0)) |>
    group_by(location, target_date) |>
    mutate(total = sum(observation)) |>
    ungroup() |>
    mutate(value = ifelse(total == 0, 0, observation / total)) |>
    mutate(type = "target")

  targets$target_date <- as.Date(targets$target_date)

  df_out_this_location <- df_model_output |>
    subset((location == this_location) & (output_type == "sample")) |>
    group_by(target_date, clade, location) |>
    summarize(mean = mean(value),
              q05 = quantile(value, probs = 0.05, na.rm = T),
              q95 = quantile(value, probs = 0.95, na.rm = T)) |>
    mutate(type = "prediction") |>
    rename(value = mean)

  df_out_this_location_2 <- df_model_output_2 |>
    subset((location == this_location) & (output_type == "sample")) |>
    group_by(target_date, clade, location) |>
    summarize(mean = mean(value),
              q05 = quantile(value, probs = 0.05, na.rm = T),
              q95 = quantile(value, probs = 0.95, na.rm = T)) |>
    mutate(type = "prediction") |>
    rename(value = mean)

  df_out_this_location_base <- df_model_output_base |>
    subset((location == this_location) & (output_type == "sample")) |>
    group_by(target_date, clade, location) |>
    summarize(mean = mean(value),
              q05 = quantile(value, probs = 0.05, na.rm = T),
              q95 = quantile(value, probs = 0.95, na.rm = T)) |>
    mutate(type = "prediction") |>
    rename(value = mean)

  # Add team column
  df_out_this_location <- df_out_this_location %>% mutate(team = "UMass")
  df_out_this_location_2 <- df_out_this_location_2 %>% mutate(team = "UGA")
  df_out_this_location_base <- df_out_this_location_base %>% mutate(team = "Baseline")

  # Combine data frames
  df_out <- bind_rows(df_out_this_location, df_out_this_location_2, df_out_this_location_base)

  targets_this_location <- targets |> subset(location == this_location)
  colnames(targets_this_location)[3] <- "clade"

  p <- ggplot(df_out, aes(x = target_date, y = value, color = team)) +
    ggtitle(paste0("Daily Observed and Predicted Proportions \n", this_location, " Nowcast Date: ", reference_date)) +
    theme(legend.position = "bottom", legend.justification = "center", legend.title = element_blank()) +
    theme(legend.text=element_text(size=rel(0.4))) +
    geom_point(data = targets_this_location,
               inherit.aes = FALSE,
               mapping = aes(x = target_date, y = value, color = "darkorange", size = total),
               alpha = 0.6) +

    geom_point(data = targets_retro_this_location,
               mapping = aes(x = date, y = value, color = "dodgerblue", size = total),
               inherit.aes = FALSE,
               alpha = 0.6) +
    geom_line() +
    geom_ribbon(aes(ymin = q05, ymax = q95, fill = team), alpha = 0.3, color = NA) +

    # Breaks decides the legend order
    # Default without breaks is in ALPHABETICAL ORDER of labels >.<
    scale_color_manual(labels = c("Baseline", "Validated Data 2025-03-25", date_obs, "UGA", "UMass"),
                       values = c("limegreen", "darkorange", "dodgerblue", "purple", "darkred"),
                       aesthetics = c("fill", "color")) +
    scale_size(name = "# of sequences", range = c(1, 4)) +
    facet_wrap(~clade)

  print(p)
}

# Close the PDF file
dev.off()

### Do Weekly versions next:

## Weekly targets (actual observed)
# targets_other_wk <- targets_other |>
#   mutate(wday = lubridate::wday(date),
#          epiweek_end = date + 7 - wday) |>
#   group_by(location, clade, epiweek_end) |>
#   summarize(count = sum(count)) |>
#   ungroup() |>
#   group_by(location, epiweek_end) |>
#   mutate(total = sum(count)) |>
#   ungroup() |>
#   mutate(value = ifelse(total == 0, 0, count/total)) |>
#   rename(date = epiweek_end) |>
#   arrange(location, date, clade)
