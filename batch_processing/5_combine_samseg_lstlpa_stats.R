#!/usr/bin/env Rscript

# Merge features from samseg and LST-lpa
# Diana Giraldo, January 2023

library(dplyr)
library(lubridate)
library(readxl)

# Inputs
samsegfile <- "/home/vlab/MS_proj/feature_tables/samseg_outputs.csv"
lstlpafile <- "/home/vlab/MS_proj/feature_tables/lstlpa_outputs.csv"
idxfile <- "/home/vlab/MS_proj/info_files/identified_patients_lorin.xlsx"

# SAMSEG estimations are in mm^3 -> convert to cm^3 
A <- read.csv(samsegfile, header = TRUE) %>%
  mutate(Date = as.Date(Date), 
         across(samseg.Intra.Cranial:samseg.Brain.Stem, ~ .x/1000))

# LST-lpa lesion load estimations
B <- read.csv(lstlpafile, header = TRUE) %>%
  mutate(Date = as.Date(Date))

# IDx file
LID = read_excel(idxfile) %>%
  select(PATID, OAZIS_PATID) %>%
  as.data.frame(.) %>%
  unique(.)

# Merge
DF <- inner_join(A, B) %>%
  rename(OAZIS_PATID = Subject, MRIdate = Date, MRIpipeline = proc_pipe) %>%
  left_join(., LID) %>%
  select(OAZIS_PATID, PATID, everything()) %>%
  select(-Session, -t0, -Month)

rm(A, B, LID)

# Calculate features
DF <- DF %>%
  mutate(samseg.Cerebral.GMCortex = samseg.Left.Cerebral.Cortex + samseg.Right.Cerebral.Cortex,
         samseg.Cerebral.WM = samseg.Right.Cerebral.White.Matter + samseg.Left.Cerebral.White.Matter,
         samseg.Ventricles = samseg.Left.Lateral.Ventricle + samseg.Right.Lateral.Ventricle +
           samseg.Right.Inf.Lat.Vent + samseg.Left.Inf.Lat.Vent + samseg.3rd.Ventricle + 
           samseg.4th.Ventricle + samseg.5th.Ventricle) %>%
  select(OAZIS_PATID:MRIpipeline, lstlpa.nLesions, samseg.Intra.Cranial, lstlpa.Lesion.Volume, everything()) 

# Normalise volumes with estimated intra-cranial volume (TIV)
DF <- DF %>%
  mutate(across(lstlpa.Lesion.Volume:samseg.Ventricles,
         ~ (.x/samseg.Intra.Cranial),
         .names = "{col}.normTIV"))

# Save info
write.csv(DF, 
          file = "/home/vlab/MS_proj/feature_tables/MRI_features_13092023.csv", 
          row.names = FALSE)

dict <- data.frame(VarName = names(DF), Description = "")
write.csv(dict, 
          file = "/home/vlab/MS_proj/feature_tables/dictionary_MRI_features_13092023.csv", 
          row.names = FALSE)

# Plot Lesion volume estimations
library(ggplot2)

plt <- ggplot(filter(DF, !is.na(MRIpipeline)), 
              aes(x = samseg.Lesions, y = lstlpa.Lesion.Volume, colour = MRIpipeline)) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", size = 0.75, colour = "gray70") +
  geom_point(size = 0.5) +
  geom_smooth(method = lm, se = FALSE, size = 0.75) +
  theme_minimal() +
  labs(x = "Lesion Volume - SAMSEG estimation", y = "Lesion Volume - LST-lpa estimation",
       colour = "MRI Processing pipeline") +
  theme(legend.position = "top") +
  scale_color_manual(values = c("#2A3585", "#78207F", "#C7325D", "#FF8166"))

plt
  

