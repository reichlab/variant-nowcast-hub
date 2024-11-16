model_output_summary <- function(target_date){
  library(arrow)
  library(yaml)
  library(knitr)
  library(kableExtra)
  library(grid)
  
  if(!(any(target_date == seq(as.Date("2024-10-09"), Sys.Date(), by = 7)))){
    stop("The target date is not on a valid Wednesday")
  }
  
  file_directory_metadata <- "./model-metadata/"
  file_directory_output <- "./model-output/"
  file_names <- list.files(file_directory_metadata) # getting the file names
  file_names <- file_names[file_names != "README.md"]
  
  Model_creator <- c() # the variable to store the model creator names
  Locations_modeled <- c() # the variable to store the locations modeled
  output_types <- c() # the variable to store the output types
  number_of_locations_modeled <- c() # the variable to store the number of locationes modeled
  j <- 1
  
  for(file in file_names){
    # checking if the modeler submitted for the week
    if(!(file.exists(paste0(file_directory_output, substr(file, 1, nchar(file) - 4),
                            "/", target_date, "-", substr(file, 1, nchar(file) - 3), "parquet")))){
      next
    }
    # reading in the modelers name
    suppressWarnings(yml_data <- yaml.load_file(paste0(file_directory_metadata, "/", file)))
    Model_creator[j] <- yml_data$team_name
    # reading in the model file
    model <- read_parquet(paste0(file_directory_output, substr(file, 1, nchar(file) - 4),
                                 "/", target_date, "-", substr(file, 1, nchar(file) - 3), "parquet"))
    # grabbing the number of locations, and output types for the model
    Locations_modeled[j] <- paste(unique(model$location), collapse = ", ")
    number_of_locations_modeled[j] <- length(unique(model$location))
    output_types[j] <- paste(unique(model$output_type), collapse = ", ")
    j <- j + 1
  }
  # making the data frame
  table <- data.frame(Model_creators = Model_creator,
                      Number_of_locations = number_of_locations_modeled,
                      Locations_modeled = Locations_modeled,
                      Output_types = output_types)
  # making the table
  save_file_name = paste0("./model_output_summary_", target_date, ".pdf")
  kable(table, format = "html", booktabs = TRUE) %>%
    kable_styling(latex_options = c("scale_down")) %>%
    column_spec(2, width = "3cm") %>%
    column_spec(3, width = "5cm") %>%
    save_kable(file = save_file_name)
}

## e.g. 
#model_output_summary(target_date = as.Date("2024-11-13"))