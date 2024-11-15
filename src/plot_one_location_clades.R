#' Plot clade data and predictions for one location
#'
#' @param this_location two letter abbreviation for state to plot
#' @param model_output_data formatted model output data
#' @param target_data formatted target data
#'
plot_one_location_clades <- function(this_location, model_output_data, target_data){
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
    ylim <- c(-4, 4)
    transftitle <- "Logit Transformed "
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
    scale_y_continuous(limits = ylim, name = "clade frequency") +
    scale_x_date(NULL, date_breaks = "3 months", date_minor_breaks = "1 month") +
    scale_size(name = "# of sequences") +
    facet_wrap(~clade) +
    ggtitle(paste(transftitle, "Observed and predicted frequencies of SARS-CoV-2 clades in", this_location))
  return(p)
}

rangeScale <- function(x){
  (x-min(x)) / (max(x)-min(x)) 
}

logit <- function(p){
  ## Multinomials might make this more complicated...!
  out <- log(p/(1-p))
  if(sum(is.na(out))){
    paste("There's ", sum(is.na(out)), " NAs.")
  }
  return( log(p/(1-p)) )
  #return( 1/(1 + exp(-p)) )
}


#' Averaging THEN Logit (need to reverse this - see below)
#' Plot clade data and predictions for one location
#'
#' @param this_location two letter abbreviation for state to plot
#' @param model_output_data formatted model output data
#' @param target_data formatted target data
#'
plot_one_location_clades_logit <- function(this_location, model_output_data, target_data){
  require(dplyr)
  require(ggplot2)
  theme_set(theme_bw())
  
  mean_data_loc <- model_output_data |>
    filter(location == this_location) |>
    group_by(target_date, clade, location) |>
    filter(value > 0) |>
    summarize(mean = mean(value),
              q10 = quantile(value, probs = 0.1),
              q90 = quantile(value, probs = 0.9)) |>
    mutate(type = "prediction",
           vlogit = logit(mean),
           q10_logit = logit(q10),
           q90_logit = logit(q90)) |>
    rename(date = target_date,
           value = mean,
           value_logit = vlogit)
  
  #mean_data_loc$scale_logit <- mean_data_loc$value_logit |> rangeScale()
  #mean_data_loc$value_logit <- mean_data_loc$vlogit |> rangeScale()
  mean_data_loc$q10_scale <- mean_data_loc$q10_logit |> rangeScale()
  mean_data_loc$q90_scale <- mean_data_loc$q90_logit |> rangeScale()

  
  View(mean_data_loc)
  
  ## Just logit the value in the df then plot loess curves?
  target_data_loc <- filter(target_data, location == this_location) |>
    mutate(value_logit = logit(value)) |>
    filter(value_logit != -Inf, value_logit != Inf) #|>
    #mutate(value_logit = rangeScale(value_logit))
  
  
  p <- mean_data_loc |>
    ggplot(aes(x=date, y=value_logit)) +
    geom_point(data = target_data_loc, aes(size = total))+
    geom_smooth(data = target_data_loc, se=FALSE, aes(weight = total))+
    geom_line(color = "red") +
    geom_ribbon(aes(ymin = q10_logit, ymax = q90_logit), fill="red", alpha = .5) +
    scale_y_continuous(limits = c(-4, 5), name = "clade frequency") +
    #scale_y_continuous(limits = c(0,1), name = "clade frequency") +
    scale_x_date(NULL, date_breaks = "3 months", date_minor_breaks = "1 month") +
    scale_size(name = "# of sequences") +
    facet_wrap(~clade) +
    ggtitle(paste("Logit Transformed - Observed and predicted frequencies of SARS-CoV-2 clades in", this_location))
  return(p)
}


#' Logit THEN average
#' Plot clade data and predictions for one location
#'
#' @param this_location two letter abbreviation for state to plot
#' @param model_output_data formatted model output data
#' @param target_data formatted target data
#'
plot_one_location_clades_logit_rev <- function(this_location, model_output_data, target_data){
  require(dplyr)
  require(ggplot2)
  theme_set(theme_bw())
  
  mean_data_loc <- model_output_data |>
    filter(location == this_location) |>
    group_by(target_date, clade, location) |>
    filter(value > 0) |>
    summarize(logit = logit(value),
              q10 = quantile(value, probs = 0.1),
              q90 = quantile(value, probs = 0.9)) |>
    mutate(type = "prediction",
           value_logit = mean(logit),
           q10_logit = logit(q10),
           q90_logit = logit(q90)) |>
    rename(date = target_date)
  
  #mean_data_loc$scale_logit <- mean_data_loc$value_logit |> rangeScale()
  #mean_data_loc$value_logit <- mean_data_loc$vlogit |> rangeScale()
  mean_data_loc$q10_scale <- mean_data_loc$q10_logit |> rangeScale()
  mean_data_loc$q90_scale <- mean_data_loc$q90_logit |> rangeScale()
  
  
  # print(summary(mean_data_loc$value_logit))
  # print(range(mean_data_loc$value_logit))
  # print(sum(is.na(mean_data_loc$value_logit)))
  
  View(mean_data_loc)
  
  ## Just logit the value in the df then plot loess curves?
  target_data_loc <- filter(target_data, location == this_location) |>
    mutate(value_logit = logit(value)) |>
    filter(value_logit != -Inf, value_logit != Inf) #|>
  #mutate(value_logit = rangeScale(value_logit))
  
  
  p <- mean_data_loc |>
    ggplot(aes(x=date, y=value_logit)) +
    geom_point(data = target_data_loc, aes(size = total))+
    geom_smooth(data = target_data_loc, se=FALSE, aes(weight = total))+
    geom_line(color = "red") +
    geom_ribbon(aes(ymin = q10_logit, ymax = q90_logit), fill="red", alpha = .5) +
    scale_y_continuous(limits = c(-4, 5), name = "clade frequency") +
    #scale_y_continuous(limits = c(0,1), name = "clade frequency") +
    scale_x_date(NULL, date_breaks = "3 months", date_minor_breaks = "1 month") +
    scale_size(name = "# of sequences") +
    facet_wrap(~clade) +
    ggtitle(paste("Logit Transformed - Observed and predicted frequencies of SARS-CoV-2 clades in", this_location))
  return(p)
}