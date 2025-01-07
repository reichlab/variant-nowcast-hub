### 
# Script to plot model output (Just UMass-HMLR for now) with data available
# at reference date (training data) and data validated through CladeTime at a 
# later date for validation purposes. 
# Currently does daily plots, but will be extended to weekly
library("dplyr")
library("ggplot2")
library("arrow")
here::i_am("src/plot_validation_data.R")
# Load validation data from CladeTime (pre-made)
# Note: this file is generated through CladeTime as is not made here, must be
# created ahead of time and path changed here
hub_path <- here::here()
df_validation <- read.csv(here::here("auxiliary-data/example-files/summarized_clades_asof_2024-10-28_on_2025-01-07.csv")) |> 
  subset(select = -c(host, country))
# Some locs have missing counts (non-present)
# e.g. subset(df_validation, (date == "2024-10-01") & (location == "TX")) # "MA"
# Resolved with tidyr::complete() 

# Meta data for getting data available on reference date
reference_date <- "2024-10-28" ## REFERENCE DATE
s3_data_date <- reference_date
targets_path_s3 <- paste0("https://covid-clade-counts.s3.amazonaws.com/",
s3_data_date, "_covid_clade_counts.parquet")
df_retro <- arrow::read_parquet(targets_path_s3)

## load in the hub locations file - convert names/abbreviations
load(file.path(hub_path, "auxiliary-data/hub_locations.rda"))
locs <- hub_locations |>
  dplyr::select(abbreviation, location_name) |>
  rename(location = location_name)

## Modify location names for df_retro
df_retro <- df_retro %>%
  left_join(locs, by = "location") %>%
  # Replace the location names with their abbreviations
  mutate(location = abbreviation) %>%
  # Remove the abbreviation column if you no longer need it
  select(-abbreviation)

# Model output, just UMASS HMLR for now
df_model_output <- arrow::read_parquet(file.path(hub_path, "model-output/UMass-HMLR/2024-10-30-UMass-HMLR.parquet"))

clades <- unique(df_model_output$clade)

colnames(df_retro)[3] <- "clade"
targets_retro <- df_retro |>
  filter(!is.na(date), date >= (as.Date(s3_data_date) - 150)) |>
  mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
  #tidyr::complete(location, date, clade, fill = list(count=0)) |>
  group_by(location, date) |>
  mutate(total = sum(count)) |>
  ungroup() |>
  mutate(value = ifelse(total == 0, 0, count/total)) |>
  mutate(type = "target")

#######

# Create a PDF file to save the plots
pdf("~/Downloads/plot_validation_by_location.pdf")
unique_locs <- sort(unique(df_model_output$location))

#this_location <- "CA"

for (this_location in unique_locs){

  targets_retro_this_location <- targets_retro |> subset((location == this_location))
  
  ## Daily targets (actual observed)
  colnames(df_validation)[3] <- "clade"
  targets <- df_validation |>
    #filter(!is.na(date), date >= "2024-01-01") |>
    mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
    #tidyr::complete(location, date, clade, fill = list(count=0)) |>
    group_by(location, date) |>
    mutate(total = sum(count)) |>
    ungroup() |>
    mutate(value = ifelse(total == 0, 0, count/total)) |>
    mutate(type = "target")
  
  targets$date <- as.Date(targets$date)
  
  ## Check for completion of observations - adds zeros where no clades observed
  # subset(targets, (date == "2024-10-01") & (location == "MA"))
  
  df_out_this_location <- df_model_output |> subset((location == this_location) & (output_type == "mean"))
  
  targets_this_location <- targets |> subset(location == this_location)
  colnames(targets_this_location)[3] <- "clade"
  
  p <- ggplot(df_out_this_location, aes(x = target_date, y = value)) + 
    ggtitle(paste0("Daily Observed and Predicted Proportions \nfor model output in ", this_location, " - 2024-10-30-UMass-HMLR")) + 
    theme(legend.position = "bottom", legend.justification = "center", legend.title = element_blank()) + 
    geom_point(data = targets_this_location, 
               inherit.aes = FALSE,  
               mapping = aes(x = date, y = value, color = "darkorange"),
               alpha = 0.6) + 
    geom_point(data = targets_retro_this_location, mapping = aes(x = date, y = value, color = "dodgerblue"),
               inherit.aes = FALSE,
               alpha = 0.6) +
    scale_color_manual(labels = c("Validated Data as of 2025-01-07", paste0("Training Data as of ", reference_date)), values = c("darkorange", "dodgerblue")) + 
    geom_line(color = "red") + 
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