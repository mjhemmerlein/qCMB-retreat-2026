# Prion Deposit Analysis Pipeline

## Overview

This project provides a user-friendly and reproducible pipeline for analyzing prion deposition in histological images. Rather than requiring extensive imaging analysis experience, this pipeline combines the machine learning-based segmentation capabilities of Ilastik and automated statistical power of R to streamline complex histological image analysis. 

The pipeline is designed to increase accessibility for researchers who may not have extensive imaging analysis experience, while maintaining the rigor and reproducibility required for scientific research. 

## Features

## Outputs
Ilastik
    - Images marked with with background, tissue, deposition
    - Segmentation masks for each image
R
    - Define deposition vs deposition on the masked images
    - Calculate percentage of tissue are that is deposition per brain region
    - Heatmap of deposition percentage per brain region
    