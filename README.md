# Prion Deposit Analysis Pipeline

> **qCMB 2026 Hackathon** · Team Hacking into the Brainframe · June 10–11, 2026

*Built at the qCMB 2026 Hackathon by Team Hacking into the Brainframe (Ayda Lewis, Megan Hammerlein, and Owen Bevis) and ChatGPT 5.5.*

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
  Percent Deposition per brain region boxplot + Heatmap
```

---

## File Naming Convention

Input images must follow this underscore-delimited naming scheme:

```
{group}_{treatment}_{tissue}_{magnification}_{sample_id}_{method}.tif
```

| Field | Description | Example |
|---|---|---|
| `group` | Experimental group / genotype | `WT`, `KO` |
| `treatment` | Treatment condition | `ctrl`, `infected` |
| `tissue` | Brain region | `cortex`, `hippocampus` |
| `magnification` | Objective used | `10x`, `20x` |
| `sample_id` | Unique sample identifier | `M01` |
| `method` | Downstream method tag | `ilastik` |

---

## Pipeline Components

### 1. Ilastik — Pixel Classification

Train a pixel classifier to label three classes in each image:

| Label | Value | Description |
|---|---|---|
| Background | `1` | Non-tissue area |
| Brain tissue | `2` | Healthy tissue |
| Deposition | `3` | Prion deposits |

**Output:** Segmentation masks (8-bit grayscale `.tif`) saved to `Masked_Images/`.

---

### 2. R — Quantification & Visualization

Two R scripts handle metadata parsing and mask analysis.

#### `pipeline.R` — Image Loading & Metadata Extraction

- Reads `.tif` images from `00_test-input/`
- Parses filenames into a structured metadata table (genotype, condition, brain region, magnification, sample ID)
- Loads each image into memory via `magick` for downstream use

**Libraries:** `tidyverse`, `magick`

#### `Image_Analysis_Pipeline.R` — Mask Quantification

- Reads segmentation masks from `Masked_Images/`
- Counts pixels per class (background, brain, deposition)
- Calculates **deposition fraction** = `deposition pixels / brain pixels`
- Combines metadata and quantification into a single tidy dataframe

**Libraries:** `tidyverse`, `stringr`, `purrr`, `EBImage`

**Key output columns:**

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
| `combined_data` table | Tidy per-image quantification with metadata |
| Deposition heatmap | % deposition per brain region, visualized across groups |
| Deposition boxplot | % deposition per brain region, grouped by treatment |

---

## Directory Structure

```
project/
├── 00_test-input/          # Raw .tif histological images
├── Masked_Images/          # Ilastik segmentation mask outputs
├── pipeline.R              # Image loading and metadata extraction
├── Image_Analysis_Pipeline.R  # Mask quantification and summary
└── README.md
```

---

## Dependencies

### R Packages
```r
install.packages(c("tidyverse", "stringr", "purrr"))
BiocManager::install("EBImage")   # for readImage()

# For pipeline.R image loading:
install.packages("magick")
```

### External Tools
- [**Ilastik**](https://www.ilastik.org/) (v1.3+) — pixel classification and mask export

---

## Getting Started

1. Train an Ilastik classifier on representative images using the three labels above.
2. Export segmentation masks to `Masked_Images/` using the batch processing module.
3. Run `pipeline.R` to load images and build the metadata table.
4. Run `Image_Analysis_Pipeline.R` to quantify deposition and generate the summary dataframe.
5. Use the output dataframe for downstream visualization (heatmaps, group comparisons).

---


