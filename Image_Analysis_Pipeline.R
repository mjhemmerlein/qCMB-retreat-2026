
# Libraries
library(tidyverse)
library(stringr)
library(purrr)

# Function to parse file names
parse_filename_metadata <- function(filepath) {
  fname <- basename(filepath)
  parts <- str_split(str_remove(fname, "\\.[^.]+$"), "_")[[1]]
  
  tibble(
    file = fname,
    group = parts[1],
    treatment = parts[2],
    tissue = parts[3],
    magnification = parts[4],
    sample_id = parts[5],
    method = paste(parts[6:length(parts)], collapse = "_")
  )
}

# Function to extract mask features
extract_mask_features <- function(mask) {
  
  tibble(
    background = sum(mask == 1, na.rm = TRUE),
    brain      = sum(mask == 2, na.rm = TRUE),
    deposition = sum(mask == 3, na.rm = TRUE)) %>%
    mutate(
      deposition_frac = deposition / brain)
}

# Function to run
process_mask_file <- function(filepath) {
  
  mask <- readImage(filepath)
  mask <- round(mask * 255)
  
  meta <- parse_filename_metadata(filepath)
  features <- extract_mask_features(mask)
  
  bind_cols(meta, features)
}

# List all files
files <- list.files("Masked_Images", full.names = TRUE)

# Generate metadata file
combined_data <- map_dfr(files, process_mask_file)



