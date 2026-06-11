# Prion Deposit Analysis Pipeline

> **qCMB 2026 Hackathon** · Team Hacking into the Brainframe · June 10–11, 2026

*Built at the qCMB 2026 Hackathon by Team Hacking into the Brainframe (Megan Hemmerlein, Diana Lowe, Owen Bevis and Ayda Lewis) and ChatGPT 5.5.*

A reproducible, accessible pipeline for quantifying prion deposition in histological images. Combines the machine learning-based segmentation of **Ilastik** with automated pixel quantification and visualization in **R**. No extensive imaging analysis experience required!

---

## Overview

Prion disease research often requires labor-intensive manual scoring of histological sections. This pipeline automates that process without requiring image analysis expertise, utilizing the machine learning based pixel classification of Ilastik and automated quantification and visualization in R.

---

## Workflow

```
Raw .tif Images
      │
      ▼
  [ Ilastik ]
  Pixel Classification
  → background / tissue / deposition
      │
      ▼
  Segmentation Masks
      │
      ▼
    [ R ]
  Pixel Counting & Metadata Parsing
  → area of deposition/area of brain tissue = % deposition
      │
      ▼
  Percent Deposition per brain region boxplot + statistical analysis
```
---

## Directory Structure

```
qCMB-retreat_2026/
├── Plot_output/          # plots from R script visualizations
├── ilastik_output/          # Ilastik segmentation mask outputs
├── .gitignore               # To ignore the .DS_store and .Rproj files
├── Image_Analysis_Pipeline_Plotting.R  # Pipeline to go from masked images to plots and summary data
├── PercentDeposition_summary.csv # Summary of the data output from ilastik, includes deposition fraction data
├── prion_pipeline_presentation.pptx  # qCMB retreat presentation :)
└── README.md
```
---

## File Naming Convention

Input images must follow this underscore-delimited naming scheme:

```
{group}_{treatment}_{tissue}_{magnification}_{sample_id}_{method}.tif
```

| Field | Description | Example |
|---|---|---|
| `group` | Experimental group / genotype | `WT`, `GtDeer`, `GtElk` |
| `treatment` | Treatment condition | `control`, `treatment` |
| `tissue` | Brain region | `cerebellum`, `midbrain`, `hippocampus`, `septum` |
| `magnification` | Objective used | `4x` |
| `sample_id` | Unique sample identifier | `M01` |
| `method` | Downstream method tag | `ilastik` |

---

## Pipeline Components

### 1. Ilastik — Pixel Classification

Train a pixel classifier to label three classes in each image, using the following methods and classifications:
  1. Trained using Ground truth metrics from manual scoring
  2. Batch processed all images using the trained classifier
  3. Manually assessed quality of masked images

| Label | Value | Description |
|---|---|---|
| Background | `1` | Non-tissue area |
| Brain tissue | `2` | Healthy tissue |
| Deposition | `3` | Prion deposits |

**Output:** Segmentation masks (8-bit grayscale `.tif`) saved to `ilastik_output/`.

---

### 2. R — Quantification & Visualization

#### `Image_Analysis_Pipeline_Plotting.R` — Image Loading, Metadata Extraction, and Mask Quantification

1. Reads `.tif` images from Alpine directory
2. Parses filenames into a structured metadata table (genotype, condition, brain region, magnification, sample ID)
3. Loads each image into memory via `EBImage` for downstream use
4. Reads segmentation masks from `ilastik_output/`
5. Counts pixels per class (background, brain, deposition)
6. Calculates **deposition fraction** = `deposition pixels / brain pixels`
7. Combines metadata and quantification into a single tidy dataframe

**Libraries:** `tidyverse`, `stringr`, `purrr`, `EBImage`, `lmertest`, `emmeans`

**Key output metadata columns:**

| Column | Description |
|---|---|
| `group` | Experimental group |
| `treatment` | Treatment condition |
| `tissue` | Brain region |
| `background` | Background pixel count |
| `brain` | Brain tissue pixel count |
| `deposition` | Deposition pixel count |
| `deposition_frac` | Fraction of brain area with deposition |

---

## Outputs

| Output | Description |
|---|---|
| Ilastik mask overlays | Images annotated with background / tissue / deposition labels |
| Segmentation masks | Grayscale `.tif` masks per image |
| PercentDeposition_summary.csv | Tidy per-image quantification with metadata |
| Deposition heatmap | % deposition per brain region, visualized across groups |
| Deposition boxplot | % deposition per brain region, grouped by treatment |

---

## Dependencies

### R Packages
```r
install.packages(c("tidyverse", "stringr", "purrr", "lmertest", "emmeans"))
BiocManager::install("EBImage")   # for readImage()

```

### External Tools
- [**Ilastik**](https://www.ilastik.org/) (v1.3+) — pixel classification and mask export

---

## Getting Started

1. Train an Ilastik classifier on representative images using the three labels and methods above.
2. Export segmentation masks to `ilastik_outputs/` using the batch processing module.
3. Run `Image_Analysis_Pipeline_Plotting.R` to load images, build the metadata table, quantify deposition and generate the summary dataframe.
5. Use the output dataframe for downstream visualization (heatmaps, group comparisons).

---


