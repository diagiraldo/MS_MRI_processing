#!/usr/bin/env Rscript

# Merge features from samseg and LST-lpa - Zuyderland dataset
# Diana Giraldo, Nov 2023

library(dplyr)
library(lubridate)

# Inputs
samsegfile <- "/home/vlab/MS_proj/feature_tables/samseg_outputs_zuy.csv"
lstlpafile <- "/home/vlab/MS_proj/feature_tables/lstlpa_outputs_zuy.csv"

# SAMSEG estimations are in mm^3 -> convert to cm^3 
A <- read.csv(samsegfile, header = TRUE) %>%
  mutate(Date = as.Date(Date), 
         across(samseg.Intra.Cranial:samseg.Brain.Stem, ~ .x/1000))

# LST-lpa lesion load estimations
B <- read.csv(lstlpafile, header = TRUE) %>%
  mutate(Date = as.Date(Date))

# Merge
DF <- inner_join(A, B) %>%
  rename(MRIdate = Date, MRIpipeline = proc_pipe) %>%
  select(-acqgroup, -zuy_pipe, -t0, -Month)

rm(A, B)

# Calculate features
DF <- DF %>%
  mutate(samseg.Cerebral.GMCortex = samseg.Left.Cerebral.Cortex + samseg.Right.Cerebral.Cortex,
         samseg.Cerebral.WM = samseg.Right.Cerebral.White.Matter + samseg.Left.Cerebral.White.Matter,
         samseg.Ventricles = samseg.Left.Lateral.Ventricle + samseg.Right.Lateral.Ventricle +
           samseg.Right.Inf.Lat.Vent + samseg.Left.Inf.Lat.Vent + samseg.3rd.Ventricle + 
           samseg.4th.Ventricle + samseg.5th.Ventricle) %>%
  select(Subject:MRIpipeline, lstlpa.nLesions, samseg.Intra.Cranial, lstlpa.Lesion.Volume, everything()) 

# Normalise volumes with estimated intra-cranial volume (TIV)
DF <- DF %>%
  mutate(across(lstlpa.Lesion.Volume:samseg.Ventricles,
                ~ (.x/samseg.Intra.Cranial),
                .names = "{col}.normTIV"))

# Save info
write.csv(DF, 
          file = "/home/vlab/MS_proj/feature_tables/MRI_features_zuy_16112023.csv", 
          row.names = FALSE)