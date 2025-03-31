### 
# Script to plot model output (UMass-HMLR default, others manually for now) 
# with data available at reference date (training data) and data validated
# through CladeTime 90+ days later for validation purposes. 

# Currently does daily plots, but will be extended to weekly
library("dplyr")
library("ggplot2")
library("arrow")
here::i_am("src/plot_validation_data.R")
           
# Load validation data from target data dirs
hub_path <- here::here()

# Using newest Hub target data format
df_validation <- arrow::read_parquet("./target-data/time-series/as_of=2025-03-25/nowcast_date=2024-12-25/timeseries.parquet")

# Meta data for getting data available on reference date
reference_date <- "2024-12-25"
s3_data_date <- as.character(as.Date(reference_date) - 2)
targets_path_s3 <- paste0("https://covid-clade-counts.s3.amazonaws.com/",
                          s3_data_date, "_covid_clade_counts.parquet")
df_retro <- arrow::read_parquet(targets_path_s3)

# Model output file, just UMass for now
df_model_output <- arrow::read_parquet(file.path(hub_path, "model-output/UMass-HMLR/2024-12-25-UMass-HMLR.parquet"))

clades <- unique(df_model_output$clade)

targets_retro <- df_retro |>
  filter(!is.na(date), date >= (as.Date(s3_data_date) - 150)) |>
  mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
  tidyr::complete(location, date, clade, fill = list(count=0)) |>
  group_by(location, date) |>
  mutate(total = sum(count)) |>
  ungroup() |>
  mutate(value = ifelse(total == 0, 0, count/total)) |>
  mutate(type = "target")

# Create a PDF file to save the plots
# Make argument to function eventually
save_path = paste0(hub_path, "/plot_validation_by_location_", reference_date, ".pdf")
#save_path = paste0(hub_path, "/plot_baseline_validation_by_location_", reference_date, ".pdf")
pdf(save_path)
unique_locs <- sort(unique(df_model_output$location))

for (this_location in unique_locs){
  
  targets_retro_this_location <- targets_retro |> subset((location == this_location))
  
  targets <- df_validation |>
    #filter(!is.na(date), date >= "2024-01-01") |>
    mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
    tidyr::complete(location, target_date, clade, fill = list(observation=0)) |>
    group_by(location, target_date) |>
    mutate(total = sum(observation)) |>
    ungroup() |>
    mutate(value = ifelse(total == 0, 0, observation/total)) |>
    mutate(type = "target")
  
  targets$target_date <- as.Date(targets$target_date)
  
  df_out_this_location <- df_model_output |> subset((location == this_location) & (output_type == "mean"))
  
  targets_this_location <- targets |> subset(location == this_location)
  colnames(targets_this_location)[3] <- "clade"
  
  p <- ggplot(df_out_this_location, aes(x = target_date, y = value)) + 
    ggtitle(paste0("Daily Observed and Predicted Proportions \nfor model output in ", this_location, " - ", reference_date, "-UMass-HMLR")) + 
    theme(legend.position = "bottom", legend.justification = "center", legend.title = element_blank()) + 
    geom_point(data = targets_this_location, 
               inherit.aes = FALSE,  
               mapping = aes(x = target_date, y = value, color = "darkorange", size = total),
               alpha = 0.6) + 
    geom_point(data = targets_retro_this_location, mapping = aes(x = date, y = value, color = "dodgerblue", size = total),
               inherit.aes = FALSE,
               alpha = 0.6) +
    scale_color_manual(labels = c("Validated Data 2025-03-26", paste0("Training Data ", reference_date)), values = c("darkorange", "dodgerblue")) + 
    scale_size(name = "# of sequences", range = c(1, 4)) +
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