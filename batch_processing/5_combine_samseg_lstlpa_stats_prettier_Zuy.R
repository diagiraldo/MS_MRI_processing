#!/usr/bin/env Rscript

# Merge features from samseg and LST-lpa after applying prettier to ZMC data
# Diana Giraldo, Sept 2024
# Last update: Sept 2024

library(dplyr)
library(lubridate)

timestr <- "20092024"

samsegfile <- sprintf("/home/vlab/MS_proj/feature_tables/samseg_outputs_prettier_ZMC_%s.csv", timestr)
lstlpafile <- sprintf("/home/vlab/MS_proj/feature_tables/lstlpa_outputs_prettier_ZMC_%s.csv", timestr)

# SAMSEG estimations are in mm^3 -> convert to cm^3 
A <- read.csv(samsegfile, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate), 
         across(samseg.Intra.Cranial:samseg.Brain.Stem, ~ .x/1000))

# LST-lpa lesion load estimations
B <- read.csv(lstlpafile, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate))

# Merge
DF <- inner_join(A, B)
rm(A, B, samsegfile, lstlpafile)

# Calculate extra features
DF <- DF %>%
  mutate(samseg.Cerebral.GMCortex = samseg.Left.Cerebral.Cortex + samseg.Right.Cerebral.Cortex,
         samseg.Cerebral.WM = samseg.Right.Cerebral.White.Matter + samseg.Left.Cerebral.White.Matter,
         samseg.Ventricles = samseg.Left.Lateral.Ventricle + samseg.Right.Lateral.Ventricle +
           samseg.Right.Inf.Lat.Vent + samseg.Left.Inf.Lat.Vent + samseg.3rd.Ventricle + 
           samseg.4th.Ventricle + samseg.5th.Ventricle) %>%
  select(Subject.folder:Month, ID:MRIpipeline, lstlpa.nLesions, samseg.Intra.Cranial, lstlpa.Lesion.Volume, everything())

# Normalise volumes with estimated intra-cranial volume (TIV)
DF <- DF %>%
  mutate(across(lstlpa.Lesion.Volume:samseg.Ventricles,
                ~ (.x/samseg.Intra.Cranial),
                .names = "{col}.normTIV"))

# Save info
write.csv(DF, 
          file = sprintf("/home/vlab/MS_proj/feature_tables/MRI_features_prettier_ZMC_%s.csv", timestr), 
          row.names = FALSE)