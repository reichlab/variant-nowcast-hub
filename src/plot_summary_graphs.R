#' save PDF plots: clades by location, daily and weekly, logit and non-logit
#'
#' @param model_output_file character string, directory under variant-nowcast-hub/[team name]/[model output parquet file]
#' @param s3_data_date character string, the date to pull data from S3 bucket. Should be a Monday.
#' @param baseline_clade clade to use as baseline for logit
#' @param hub_path character string, path to the root of the hub from the current working directory,
#' defaults to assume that variant-nowcast-hub/src is the working directory
#' @param save_path path to where files will be saved, relative to the working directory
#' @param page_by_location binary, if TRUE, each page of saved plots is for one location faceted by clade,
#' if FALSE, each page is for one clade faceted by location

#'
#' @examples
#' plot_summary_graphs(model_output_file = "LANL-CovTransformer/2024-11-13-LANL-CovTransformer.parquet",
#'                     s3_data_date = "2024-11-11")
plot_summary_graphs <- function(
    model_output_file = NULL,
    s3_data_date = NULL,
    baseline_clade = "24A",
    hub_path = "../",
    save_path = "~/Downloads/",
    page_by_location = TRUE){
  require(arrow)
  require(dplyr)
  options(dplyr.summarise.inform = FALSE) # Suppress message output for dplyr use

  # Model output data from model_output
  dat_path <- paste(hub_path,"model-output/", model_output_file, sep = "")
  dat <- read_parquet(dat_path)

  model_id <- sub("/.*", "", model_output_file)

  ## load in the hub locations file
  load(paste(hub_path, "auxiliary-data/hub_locations.rda", sep=""))
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

  ### plots on probability scale

  ## Weekly plots
  save_path_weekly = paste(save_path, model_id, "_weekly_", s3_data_date, ".pdf", sep = "")
  suppressMessages(save_plots(model_output_data = dat,
             target_data = targets_other_wk,
             save_path = save_path_weekly,
             page_by_location = page_by_location))


  ## Daily plots
  save_path_daily = paste(save_path, model_id, "_daily_", s3_data_date, ".pdf", sep = "")
  suppressMessages(save_plots(model_output_data = dat,
             target_data = targets_other_wk,
             save_path = save_path_daily,
             page_by_location = page_by_location))

  ### plots on logit scale

  samples <- dat[dat$output_type == "sample", ]

  ## compute logit-scale values for each sample
  model_output_logit <- merge(samples,
                              samples[samples$clade == baseline_clade,
                                      c("target_date", "output_type_id", "value")],
                by = c("target_date", "output_type_id"),
                suffixes = c("", ".base"),
                all.x = TRUE)
  model_output_logit$logitval <- log(model_output_logit$value) - log(model_output_logit$value.base)
  model_output_logit$value.base <- NULL
  model_output_logit$value <- model_output_logit$logitval
  model_output_logit$logitval <- NULL

  ## compute logit-scale target data at weekly scale
  target_logit_wk <- merge(targets_other_wk,
                           targets_other_wk[targets_other_wk$clade == baseline_clade,
                                            c("date", "location", "value")],
                          by = c("date", "location"), suffixes = c("", ".base"),
                          all.x = TRUE)
  target_logit_wk <- target_logit_wk[target_logit_wk$value > 0 & target_logit_wk$value.base > 0, ]
  target_logit_wk$logitval <- log(target_logit_wk$value) - log(target_logit_wk$value.base)
  target_logit_wk$value.base <- NULL
  target_logit_wk$value <- target_logit_wk$logitval
  target_logit_wk$logitval <- NULL

  ## compute logit scale target data at daily scale
  target_logit <- merge(targets_other, targets_other[targets_other$clade == baseline_clade,
                                                    c("date", "location", "value")],
                       by = c("date", "location"), suffixes = c("", ".base"), all.x = TRUE)
  target_logit <- target_logit[target_logit$value > 0 & target_logit$value.base > 0, ]
  target_logit$logitval <- log(target_logit$value) - log(target_logit$value.base)
  target_logit$value.base <- NULL
  target_logit$value <- target_logit$logitval
  target_logit$logitval <- NULL

  ## Logit weekly plots
  save_path_weekly_logit = paste(save_path, model_id, "_weekly_logit_", s3_data_date, ".pdf", sep = "")
  suppressMessages(save_plots(model_output_data = model_output_logit,
             target_data = target_logit_wk,
             save_path = save_path_weekly_logit,
             page_by_location = page_by_location))


  ## Logit plots daily
  save_path_daily_logit = paste(save_path, model_id, "_daily_logit_", s3_data_date, ".pdf", sep = "")
  suppressMessages(save_plots(model_output_data = model_output_logit,
             target_data = target_logit,
             save_path = save_path_daily_logit,
             page_by_location = page_by_location))
}


#' helper function to save the plots
#'
#' @param model_output_data model output data to plot
#' @param target_data target data to plot
#' @param save_path path to save file to
#' @param page_by_location binary, if TRUE, each page of saved plots is for one location faceted by clade,
#' if FALSE, each page is for one clade faceted by location
#'
#' @return nothing, just saves the plots
save_plots <- function(model_output_data,
                       target_data,
                       save_path,
                       page_by_location = TRUE) {
  if(page_by_location){
    plots <- lapply(unique(model_output_data$location), function(.x)
      plot_one_location(this_location = .x,
                        model_output_data = model_output_data,
                        target_data = target_data))
  } else {
    plots <- lapply(unique(model_output_data$clade), function(.x)
      plot_one_clade(this_clade = .x,
                     model_output_data = model_output_data,
                     target_data = target_data))
  }
  ggsave(save_path,
         gridExtra::marrangeGrob(plots, nrow=1, ncol=1),
         width = 12,
         height = 8)
}

#' Plot clade data and predictions for one location
#'
#' @param this_location two letter abbreviation for state to plot
#' @param model_output_data formatted model output data
#' @param target_data formatted target data
#'
plot_one_location <- function(this_location, model_output_data, target_data){
  require(dplyr)
  require(ggplot2)
  theme_set(theme_bw())

  mean_data_loc <- model_output_data |>
    filter(location == this_location) |>
    group_by(target_date, clade, location) |>
    summarize(mean = mean(value),
              q10 = quantile(value, probs = 0.1),
              q90 = quantile(value, probs = 0.9)) |>
    mutate(type = "prediction") |>
    rename(date = target_date,
           value = mean)

  target_data_loc <- filter(target_data, location == this_location)

  if (min(target_data_loc$value) < 0 | max(target_data_loc$value) > 1) {
    ylim <- c(NA, NA) ## ensures that all data are plotted
    transftitle <- "Logit Transformed"
  } else {
    ylim <- c(0, 1)
    transftitle <- ""
  }

  p <- mean_data_loc |>
    ggplot(aes(x=date, y=value)) +
    geom_point(data = target_data_loc, aes(size = total))+
    geom_smooth(data = target_data_loc, se=FALSE, aes(weight = total))+
    geom_line(color = "red") +
    geom_ribbon(aes(ymin = q10, ymax = q90), fill="red", alpha = .5) +
    scale_y_continuous(name = "clade frequency") +
    coord_cartesian(ylim = ylim) +
    scale_x_date(NULL, date_breaks = "3 months", date_minor_breaks = "1 month") +
    scale_size(name = "# of sequences") +
    facet_wrap(~clade) +
    ggtitle(paste(transftitle, "Observed and predicted frequencies of SARS-CoV-2 clades in", this_location))
  return(p)
}

#' Plot clade data and predictions for one clade, all locations
#'
#' @param this_clade clade name
#' @param model_output_data formatted model output data
#' @param target_data formatted target data
#'
plot_one_clade <- function(this_clade, model_output_data, target_data){
  require(dplyr)
  require(ggplot2)
  theme_set(theme_bw())

  mean_data_loc <- model_output_data |>
    filter(clade == this_clade) |>
    group_by(target_date, clade, location) |>
    summarize(mean = mean(value),
              q10 = quantile(value, probs = 0.1),
              q90 = quantile(value, probs = 0.9)) |>
    mutate(type = "prediction") |>
    rename(date = target_date,
           value = mean)

  target_data_clade <- filter(target_data, clade == this_clade)

  if (min(target_data_clade$value) < 0 | max(target_data_clade$value) > 1) {
    ylim <- c(NA, NA) ## ensures that all data are plotted
    transftitle <- "Logit Transformed"
  } else {
    ylim <- c(0, 1)
    transftitle <- ""
  }

  p <- mean_data_loc |>
    ggplot(aes(x=date, y=value)) +
    geom_point(data = target_data_clade, aes(size = total))+
    geom_smooth(data = target_data_clade, se=FALSE, aes(weight = total))+
    geom_line(color = "red") +
    geom_ribbon(aes(ymin = q10, ymax = q90), fill="red", alpha = .5) +
    scale_y_continuous(limits = ylim, name = "clade frequency") +
    scale_x_date(NULL, date_breaks = "3 months", date_minor_breaks = "1 month") +
    scale_size(name = "# of sequences") +
    facet_wrap(~location) +
    ggtitle(paste(transftitle, "Observed and predicted frequencies of SARS-CoV-2 clade", this_clade))
  return(p)
}
