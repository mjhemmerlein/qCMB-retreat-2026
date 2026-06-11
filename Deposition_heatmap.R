
# Libraries
library(tidyverse)
library(stringr)
library(purrr)
library(EBImage)

img <- readImage("Masked_Images/GtDeer_mask/cerebellum_4x_mask/GtDeer_treatment_cerebellum_4x_76_mask.tif")
img = as.data.frame(img)

