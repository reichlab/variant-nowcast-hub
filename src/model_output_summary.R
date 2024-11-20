model_summary <- function(target_date, file_path_to_metadata = "../model-metadata", file_path_to_output = "../model-output/"
                          , file_path_for_txt_file = "../model_output_summary_" ){

  target_date <- as.Date(target_date)
  too_old <- target_date < "2024-10-09"
  not_wednesday <- as.POSIXlt(target_date, tz = "UTC")$wday != 3
  if(too_old || not_wednesday){
    stop("The target date is not on a valid Wednesday")
  }
  file_names <- list.files(file_path_to_metadata) # getting the file names
  file_names <- file_names[file_names != "README.md"]

  Model_creator <- c() # the variable to store the model creator names
  Locations_modeled <- c() # the variable to store the locations modeled
  locations_not_modeled <- c() # the variable to store the locations not modeled
  output_types <- c() # the variable to store the output types
  number_of_locations_modeled <- c() # the variable to store the number of locationes modeled
  model_names <- c() # the names of the models
  all_locations <- c(state.abb, "PR", "DC") # all the possible locations to model
  j <- 1

  for(file in file_names){
    # checking if the modeler submitted for the week
    if(!(file.exists(paste0(file_path_to_output, substr(file, 1, nchar(file) - 4),
                            "/", target_date, "-", substr(file, 1, nchar(file) - 3), "parquet")))){
      next
    }
    # reading in the modelers name
    suppressWarnings(yml_data <- yaml::yaml.load_file(paste0(file_path_to_metadata, "/", file)))
    Model_creator[j] <- yml_data$team_name
    # reading in the model file
    model <- arrow::read_parquet(paste0(file_path_to_output, substr(file, 1, nchar(file) - 4),
                                        "/", target_date, "-", substr(file, 1, nchar(file) - 3), "parquet"))
    # grabbing the number of locations, and locations modeled for the model
    loc_modeled <- unique(model$location) # the locations modeled as a vector
    loc_not_modeled <- "" # all the locations not modeled as a string
    Locations_modeled[j] <- paste(loc_modeled, collapse = ", ")
    number_of_locations_modeled[j] <- length(unique(model$location))
    # finding all the locations not modeled
    if(number_of_locations_modeled[j] == 52){
      loc_not_modeled <- "All locations modeled"
    } else{
      for(loc in all_locations){
        if(!(any(loc == loc_modeled))){
          loc_not_modeled = paste(loc_not_modeled,loc, sep= ",")
        }
      }
      loc_not_modeled <- substr(loc_not_modeled, 2, nchar(loc_not_modeled)) # removing the extra comma at the start
    }
    locations_not_modeled[j] <- loc_not_modeled
    # getting the output types and the model names
    output_types[j] <- paste(unique(model$output_type), collapse = ", ")
    model_names[j] <- substr(file, 1, nchar(file) - 4)
    j <- j + 1
  }
  # reading the information into a txt file
  save_file_name = paste0(file_path_for_txt_file, target_date, ".txt")
  cat(paste("Summary of submissions for", target_date), file = save_file_name)
  for(i in 1:length((Model_creator))){
    cat("\n", file = save_file_name, append = T)
    cat(paste("Model creators:", Model_creator[i], "\n"), file = save_file_name, append = T)
    cat(paste("Model name:", model_names[i], "\n" ), file = save_file_name, append = T)
    cat(paste("Output types:", output_types[i], "\n"), file = save_file_name, append = T)
    cat(paste("Number of locations modeled:", number_of_locations_modeled[i], "\n"), file = save_file_name, append = T)
    cat(paste("Locations modeled:", Locations_modeled[i], "\n"), file = save_file_name, append = T)
    cat(paste("Locations not modeled:", locations_not_modeled[i], "\n"), file = save_file_name, append = T)
  }
}
#model_summary(target_date = as.Date("2024-11-13"))
