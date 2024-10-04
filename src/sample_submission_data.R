## Script that generates sample submission data to pass validation checks for
## the forecasting hub
## It's not particularly efficient but it's easy to understand

## Function to generate simulated data
# Uses the Dirichlet distribution to generate random proportions of clades
require(brms) # for data simulation
require(arrow) # for parquet writing


sim_model_output <- function(locations = c("AL", "AZ", "CA", "CO", "DE"), 
                             alpha = c(3,3,2,2,1,1),
                             test_clades = c("24A", "24B", "24C", "24E", "recombinant", "other"),
                             target_date = seq(as.Date("2024-09-01"), as.Date("2024-10-12"), by = "1 days"),
                             nowcast_date = "2024-10-02",
                             n_samp = 100,
                             seed = 42
){
  ## Simulate data in appropriate model_output format
  #' @locations Vector of location abbreviations e.g. c("MA", ...)
  #' @alpha Parameters for rdirichlet for length(test_clades)
  #' @test_clades Clades for the weekly forecasts
  #' @target_date Forecast dates
  #' @nowcast_date Nowcast date
  #' @n_samp Number of samples per location (100 required,available for testing)
  #' @seed Set random seed value for RNG
  
  set.seed(seed)
  
  # Columns to be created for output
  target_date_col = c()
  output_type_id_col = c()
  loc_col = c()
  clade_col = c()
  value_col = c()
  
  # Create observations using dirichlet distribution for proportions
  for(loc in locations){
    for(date in target_date){
      for(sample_pt in 0:(n_samp-1)) {
        # Create random proportions with prob alpha for each sample point
        props <- rdirichlet(1, alpha = alpha)
        colnames(props) <- test_clades # attach name of clades
        
        for(clade in test_clades){
          # Format "AL00, AL01, ..."
          output_type_id_col <- c(output_type_id_col,
                                  paste(loc, 
                                        formatC(sample_pt, 
                                                width = 2, 
                                                flag = "0"), 
                                        sep = ""))
          target_date_col <- c(target_date_col, date)
          loc_col <- c(loc_col, loc)
          clade_col <- c(clade_col, clade)
          value_col <- c(value_col, as.vector(props[, clade]))
          
          # Specific date for nowcast
          nowcast_date_col <- rep(nowcast_date, length(target_date_col))
          
          # Just sample output for now
          output_type_col <- rep("sample", length(target_date_col))
          
        }
      }
    }
  }
  
  # Create data frame for convenient output
  df <- data.frame(nowcast_date =  as.Date(nowcast_date_col),
                   target_date = as.Date(target_date_col),
                   clade = clade_col, 
                   location = loc_col,
                   output_type = output_type_col,
                   output_type_id = output_type_id_col,
                   value = value_col
  )
  
  return(df)
}

df_sim <- sim_model_output()

# Note: Make sure parquet file is in the `model-output` folder 
# when using hubValidations::validate_model_data
arrow::write_parquet(df_sim, "./2024-10-02-umass-validtestsubmission.parquet")
hubValidations::validate_model_data("./variant-nowcast-hub", 
                                    "2024-10-02-umass-validtestsubmission.parquet")