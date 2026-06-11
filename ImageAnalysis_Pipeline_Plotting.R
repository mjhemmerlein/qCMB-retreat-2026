
# Libraries
library(tidyverse)
library(stringr)
library(purrr)
library(EBImage)
library(lmerTest)
library(emmeans)

files <- list.files(
  "ilastik_output/",
  full.names = TRUE,
  recursive = TRUE
)

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
  
  meta <- parse_filename_metadata(filepath)
  features <- extract_mask_features(mask)
  
  bind_cols(meta, features)
}


# Generate metadata file
combined_data <- map_dfr(files, process_mask_file)
combined_data$group_treatment = paste0(combined_data$group, "_", combined_data$treatment)
combined_data$deposition_percent = combined_data$deposition_frac * 100


# Plot the data
mycolors = c(
  "GtDeer_treatment" = "orange",
  "GtElk_treatment" = "pink",
  "WT_control" = "lightblue"
)

combined_data %>%
  ggplot(aes(x = group_treatment, y = deposition_percent, fill = group_treatment)) +
  geom_boxplot(outlier.shape = NA) +
  geom_jitter(width = 0.08, alpha = 0.5, size = 2) +
  facet_wrap(~ tissue, scales = "free_y") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_fill_manual(values = mycolors) +
  labs(
    x = "Treatment Group",
    y = "Percent Deposition\n(Deposition Area / Brain Area)")

#ggsave("Plot_output/BrainRegion.png", width = 8, height = 6, dpi = 300)

combined_data %>%
  ggplot(aes(x = tissue, y = deposition_percent, fill = group_treatment)) +
  geom_boxplot(outlier.shape = NA) +
  facet_wrap(~ group_treatment) +
  geom_jitter(width = 0.08, alpha = 0.5, size = 2) +
  theme_bw() +
  theme(legend.position = "none") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_fill_manual(values = mycolors) +
  labs(
    x = "Brain Region",
    y = "Percent Deposition\n(Deposition Area / Brain Area)")

#ggsave("Plot_output/Genotype.png", width = 8, height = 6, dpi = 300)

#write.csv(combined_data, "PercentDeposition_summary.csv")

# Statistics

Genotype <- lm(
  deposition_percent ~ group_treatment * tissue,
  data = combined_data)

anova(Genotype)

emmeans(Genotype, pairwise ~ group_treatment | tissue)


# How does genotype impact percent deposition in the brain regions?
Genotype <- lm(
  deposition_percent ~ group_treatment * tissue,
  data = combined_data)

anova(Genotype)

emmeans(Genotype, pairwise ~ tissue | group_treatment)





