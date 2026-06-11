################################################################################
### qCMB 2026 Hackathon ################
### Team Hacking into the Brainframe ###
### 06/10/2026 - 06/11/2026 ############
########################################

########################################
### Load libraries #####################
########################################

library(tidyverse)
library(magick)

########################################
### Get lists of data ##################
########################################

#Set input directory
inputdir <- "00_test-input"

# Get list of files
files <- list.files(inputdir, full.names = TRUE, recursive = TRUE)

# Initialize an empty dataframe to hold metadata
metadata_df <- setNames(data.frame(matrix(ncol = 6, nrow = 0)),
         c("Image_num", "Genotype", "Condition", 
           "Brain_Region", "Magnification", "Sample"))

# Loop over the sorted list, where "image" is the full path to an image
for (image in files) {
  # extract the name of the file, excluding the path and the ".tif"
  fname <- str_extract(basename(image), "(?:(?!\\.tif).)*")
  
  # Create a unique identifier for each image
  Image_num <- paste0("Image", 
                      # Ensures numbers 1-9 start with 0
                      str_pad(nrow(metadata_df) + 1, 2, pad = "0"))
  
  # Split the metadata information from the base filename
  metadata <- str_split(fname, "_")
  
  # Append unique image identifier to the beginning of the vector
  metadata <- append(metadata[[1]], Image_num, after = 0)
  
  # insert extracted metadata into the dataframe
  metadata_df[nrow(metadata_df) + 1,] <- metadata
  
  # create a variable with the unique identifier created above, 
  # assign it the value of an image object created with image_read()
  assign(Image_num, image_read(image))
}
