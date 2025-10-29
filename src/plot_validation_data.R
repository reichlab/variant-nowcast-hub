###
# Script to plot model output (UMass-HMLR default, others manually for now)
# with data available at reference date (training data) and data validated
# through CladeTime 90+ days later for validation purposes.


library("dplyr")
library("ggplot2")
library("arrow")
options(dplyr.summarise.inform = FALSE) # Suppress message output for dplyr use

# Load validation data from target data dirs
#hub_path <- here::here()

#' function create_validation_plots
#' @param nowcate_date the date for which the models are plotted, a date object, should be a Wednesday after 10-09-24
#' @param models, character vector, the full names of the models to be plotted, i.e. c("UMass-HMLR)
#' @param hub_path the path to the hub, defualt is .. as the script is meant to be ran out of the src folder
#' @param save_path where the output should be saved, defualt is .., for the hub main page
#' @example create_validation_plots(nowcast_date = as.Date("2024-12-25"), models = c("UMass-HMLR","Hub-baseline", "UGA-multicast"))
create_validation_plots <- function(nowcast_date, models, hub_path = "..", save_path = ".."){
  #putting the models in alphabetical order
  models <- sort(models)
  # ensuring that nowcast_date is a date
  nowcast_date <- as.Date(nowcast_date)

  validation_path <- file.path(hub_path,
                               "target-data",
                               "oracle-output",
                               paste0("nowcast_date=",
                                      nowcast_date),
                               "oracle.parquet")
  df_validation <- arrow::read_parquet(validation_path)
  # getting the data for the nowcast date
  df_retro_path <- file.path(hub_path,
                             "target-data",
                             "time-series",
                             paste0("as_of=", as.Date(nowcast_date) - 1),
                             paste0("nowcast_date=", nowcast_date),
                             "timeseries.parquet")
  df_retro <- arrow::read_parquet(df_retro_path)
  # loading the selected models
  models_list <- list()
  for(model in models){
    model_path <- file.path(hub_path,
                            "model-output",
                            model,
                             paste0(nowcast_date, "-", model, ".parquet"))
    df_model_output <- arrow::read_parquet(model_path)
    models_list[[model]] <- df_model_output
  }
  clades <- unique(models_list[[models[1]]]$clade)
  targets_retro <- df_retro |>
    filter(!is.na(target_date), target_date >= (as.Date(nowcast_date) - 150)) |>
    mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
    tidyr::complete(location, target_date, clade, fill = list(observation=0)) |>
    group_by(location, target_date, clade) |>
    summarise(observation = sum(observation, na.rm = TRUE)) |>
    mutate(total = sum(observation)) |>
    mutate(value = ifelse(total == 0, 0, observation/total)) |>
    ungroup() |>
    mutate(type = "target")
  # Create a PDF file to save the plots
  save_path_full = file.path(save_path,
                             paste0("plot_validation_by_location_", nowcast_date, ".pdf"))
  pdf(save_path_full)
  # getting the names for the locations
  unique_locs <- sort(c(state.abb, "PR", "DC"))

  # string for printing purposes
  date_obs <- paste0("Available Data ", nowcast_date)

  for (this_location in unique_locs){
    excluded_models <- c()
    targets_retro_this_location <- targets_retro |> subset((location == this_location))

    targets <- df_validation |>
      mutate(clade = ifelse(clade %in% clades, clade, "other")) |>
      tidyr::complete(location, target_date, clade, fill = list(oracle_value=0)) |>
      group_by(location, target_date, clade) |>
      summarise(oracle_value = sum(oracle_value, na.rm = TRUE)) |>
      mutate(total = sum(oracle_value)) |>
      mutate(value = ifelse(total == 0, 0, oracle_value/total)) |>
      ungroup() |>
      mutate(type = "target")
    targets$target_date <- as.Date(targets$target_date)
    df_out <- data.frame()
    for(model in models){
      df_out_this_location <- models_list[[model]] |>
        subset((location == this_location) & (output_type == "sample")) |>
        group_by(target_date, clade, location) |>
        summarize(mean = mean(value),
                  q05 = quantile(value, probs = 0.05, na.rm = T),
                  q95 = quantile(value, probs = 0.95, na.rm = T)) |>
        mutate(type = "prediction") |>
        rename(value = mean)
      # checking if predictions were made for this location
      if(nrow(df_out_this_location) == 0){
        excluded_models[length(excluded_models) + 1] <- model
        next
      }
      # add team column
      df_out_this_location <- df_out_this_location %>% mutate(team = model)
      # Combine data frames
      df_out <- bind_rows(df_out, df_out_this_location)
    }



    targets_this_location <- targets |> subset(location == this_location)
    colnames(targets_this_location)[3] <- "clade"
    models_with_predictions <- setdiff(models, excluded_models)

    # define names for legend ordering
    validated_label <- paste0("Validated Data: ", as.Date(nowcast_date + 91))
    nowcast_label   <- paste0("Nowcast Date: ", as.Date(nowcast_date))
    obs_label       <- as.character(date_obs)

    # manually specify breaks in the desired order
    legend_order <- c(validated_label, nowcast_label, obs_label, models_with_predictions)

    p <- ggplot(df_out, aes(x = target_date, y = value, color = team)) +
      ggtitle(paste0("Daily Observed and Predicted Proportions \n",
                     this_location, " Nowcast Date: ", nowcast_date)) +
      theme(
        legend.position = "bottom",
        legend.justification = "center",
        legend.title = element_blank(),
        legend.text = element_text(size = rel(0.4))
      ) +
      geom_point(
        data = targets_this_location,
        inherit.aes = FALSE,
        mapping = aes(x = target_date, y = value, color = validated_label, size = total),
        alpha = 0.6
      ) +
      geom_point(
        data = targets_retro_this_location,
        mapping = aes(x = target_date, y = value, color = obs_label, size = total),
        inherit.aes = FALSE,
        alpha = 0.6
      ) +
      geom_line() +
      geom_ribbon(aes(ymin = q05, ymax = q95, fill = team), alpha = 0.3, color = NA) +
      geom_vline(
        xintercept = as.Date(nowcast_date),
        color = "red", linewidth = 0.4, linetype = "dashed"
      ) +
      scale_color_manual(
        name   = NULL,
        breaks = legend_order,  # <<---- sets the order in the legend
        values = c(
          # must include colors for all elements in legend_order
          setNames(
            c("darkorange", "red", "dodgerblue",
              rep_len(c("purple", "darkred", "limegreen", "darkblue", "black"), length(models_with_predictions))),
            legend_order
          )
        ),
        aesthetics = c("fill", "color")
      ) +
      scale_size(name = "# of sequences", range = c(1, 4)) +
      facet_wrap(~clade)

    print(p)

  }

  # Close the PDF file
  dev.off()
}
