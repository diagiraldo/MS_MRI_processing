#!/usr/bin/env Rscript

# Acquisition Info - MRI from Zuyderland
# Diana Giraldo, Nov 2023

library(dplyr)
library(lubridate)
library(tidyr)
library(ggplot2)

# Input: File with acquisition info
acqfile <- "/home/vlab/MS_proj/info_files/acquisition_info_zuyderland.tsv"
scrdir <- "/home/vlab/MS_MRI_processing/data"

# Read table with info extracted from DICOMS
DF <- read.table(acqfile, sep = "\t", header = TRUE, colClasses = "character") %>%
  mutate(across(c(Slice.Thickness, Spacing.Between.Slices, Flip.Angle,
                  Repetition.Time, Echo.Time, Inversion.Time,
                  n.dcm.infolder, n.Instances,
                  DiffusionB.Value,
                  Magnetic.Field.Strength), 
                as.numeric),
         Study.Date = ymd(as.Date(Study.Date))) %>%
  select(-any_of(c("Instance.Creation.Date", 
                   "Acquisition.Date",
                   "Patient.Birth.Date"))) %>%
  filter(!is.na(Patient.Position), 
         n.dcm.infolder > 10) %>%
  mutate(Inversion.Time = ifelse(is.na(Inversion.Time), 0, Inversion.Time),
         DiffusionB.Value = ifelse(DiffusionB.Value > 8000, NA, DiffusionB.Value))
#         is.na(Inversion.Time) | Inversion.Time > 180) # Those inversion times are for spinal cord

# Some labels we can be sure about
DF <- DF %>%
  mutate(Img.Contrast = case_when(
    (DiffusionB.Value > 0) ~ "DWI",
    (Manufacturer.Model.Name == "Avanto_fit" & Repetition.Time > 8000 & Echo.Time > 70 & Inversion.Time > 2400) ~ "FLAIR",
    (Manufacturer.Model.Name == "Avanto_fit" & Repetition.Time < 1250 & Repetition.Time > 300 & Echo.Time < 30 & Echo.Time > 7) ~ "T1W",
    (Manufacturer.Model.Name == "Avanto_fit" & Repetition.Time < 4 & Echo.Time < 4) ~ "Spoiled", #dynamic contrast-enhanced MRI, Angiography?
    (Manufacturer.Model.Name == "Avanto_fit" & grepl("DIFFUSION", Image.Type)) ~ "DWI",
    (Manufacturer.Model.Name == "Avanto_fit" & Repetition.Time >= 5000 & Repetition.Time <= 8000 & Echo.Time > 95 & Echo.Time < 100) ~ "T2W",
    (Manufacturer.Model.Name == "Skyra" & Repetition.Time == 9000 & Echo.Time == 81 & Inversion.Time == 2500) ~ "FLAIR",
    (Manufacturer.Model.Name == "Skyra" & Repetition.Time > 5800 & Repetition.Time < 7500 & Echo.Time > 85 & Echo.Time < 120) ~ "T2W",
    (Manufacturer.Model.Name == "Skyra" & grepl("DIFFUSION", Image.Type)) ~ "DWI",
    (Manufacturer.Model.Name == "Skyra" & Repetition.Time < 1000 & Repetition.Time > 500 & Echo.Time < 11 & Echo.Time > 5) ~ "T1W",
    (Manufacturer.Model.Name == "Skyra" & Inversion.Time > 500 & Inversion.Time < 1000) ~ "T1W",
    (Manufacturer.Model.Name == "Achieva" & Repetition.Time < 1000 & Repetition.Time > 300 & Echo.Time < 20 & Echo.Time > 8) ~ "T1W",
    (Manufacturer.Model.Name == "Achieva" & Repetition.Time >= 9000 & Echo.Time > 100 & Inversion.Time >= 2400) ~ "FLAIR",
    (Manufacturer.Model.Name == "Achieva" & Repetition.Time >= 3400 & Repetition.Time <= 6000 & Echo.Time == 100) ~ "T2W",
    (Manufacturer.Model.Name == "Achieva" & Repetition.Time < 4100 & Repetition.Time > 3300 & Echo.Time < 82 & Echo.Time > 70 & grepl("ADC", Image.Type)) ~ "DWI",
    (Manufacturer.Model.Name == "Avanto" & Repetition.Time < 1000 & Repetition.Time > 350 & Echo.Time < 20 & Echo.Time > 5) ~ "T1W",
    (Manufacturer.Model.Name == "Avanto" & Inversion.Time > 500 & Inversion.Time < 1000) ~ "T1W",
    (Manufacturer.Model.Name == "Avanto" & Repetition.Time >= 3800 & Repetition.Time <= 5000 & Echo.Time == 101) ~ "T2W",
    (Manufacturer.Model.Name == "Avanto" & Repetition.Time >= 10000 & Echo.Time > 95 & Inversion.Time > 2400) ~ "FLAIR",
    (Manufacturer.Model.Name == "Avanto" & Scanning.Sequence == "EP" & grepl("DIFFUSION", Image.Type)) ~ "DWI",
    (Manufacturer.Model.Name == "MAGNETOM EXPERT plus" & Scanning.Sequence == "IR") ~ "FLAIR",
    TRUE ~ NA_character_
  ))

# Recode Scanning.Sequence and Sequence.Variant(?)
DF <- DF %>%
  mutate(SS.GR = grepl("GR", Scanning.Sequence),
         SS.EP = grepl("EP", Scanning.Sequence),
         SS.SE = grepl("SE", Scanning.Sequence),
         SS.IR = grepl("IR", Scanning.Sequence),
         SS.RM = grepl("RM", Scanning.Sequence),
         SV.MP = grepl("MP", Sequence.Variant),
         SV.MTC = grepl("TC", Sequence.Variant),
         SV.SP = grepl("SP", Sequence.Variant),
         SV.OSP = grepl("OSP", Sequence.Variant),
         SV.SK = grepl("SK", Sequence.Variant),
         SV.SS = grepl("SS", Sequence.Variant),
         has.b.value = !is.na(DiffusionB.Value) & DiffusionB.Value > 0)

################################################################################
# Identify FLAIR in other scanners
library(rpart)
library(rpart.plot)
library(caret)

id_vars <- c("Subject", "Session", "InfoName")
acq_vars <- c("Manufacturer.Model.Name",
              "SS.GR", "SS.EP", "SS.SE", "SS.IR", "SS.RM",
              "SV.MP", "SV.MTC", "SV.SP", "SV.OSP", "SV.SK", "SV.SS",
              "MR.Acquisition.Type",
              "Repetition.Time", "Echo.Time", "Inversion.Time", "Flip.Angle",
              "has.b.value", "Magnetic.Field.Strength")
lbl_vars <- c("Img.Contrast")

# Training Set
A <- DF %>%
  filter(!is.na(Img.Contrast)) %>%
  select(all_of(c(id_vars, acq_vars, lbl_vars))) %>%
  mutate(across(all_of(lbl_vars), as.factor))

# Train a decision tree
set.seed(1987)
tree <- rpart(Img.Contrast ~., 
              data = select(A, -any_of(c(id_vars, "Manufacturer.Model.Name"))),
              cp = 0.0001)

# Evaluate
rpart.plot(tree)
printcp(tree)
#rpart.rules(tree)
#plotcp(tree)
confusionMatrix(predict(tree, A, type = 'class'), A$Img.Contrast)

# Save decision tree
saveRDS(tree, file = sprintf("%s/decisiontree_imgcontrast.rda", scrdir))

# Testing Set
B <- DF %>%
  filter(is.na(Img.Contrast)) %>%
  select(all_of(c(id_vars, acq_vars)))

B <- mutate(B, 
            pred.Img.Contrast = predict(tree, B, type = 'class'))

# Sample to check
set.seed(1987)
s <- sample(1:nrow(B), 10)
testsample <- B[s,]
testsample

# Incorporate prediction
DF <- DF %>%
  mutate(pred.Img.Contrast = predict(tree, DF, type = 'class')) %>%
  separate(InfoName, c("FolderName", "dcmset"), sep = 8, remove = FALSE) %>%
  select(Subject, Session, FolderName, dcmset,
         Study.Date, Series.Time, Start.Time, End.Time, Acquisition.Duration,
         Manufacturer, Manufacturer.Model.Name, Magnetic.Field.Strength,
         Scanning.Sequence, Sequence.Variant, Scan.Options,
         Repetition.Time, Echo.Time, Inversion.Time, Flip.Angle,
         MR.Acquisition.Type, Slice.Thickness, Spacing.Between.Slices,
         Pixel.Spacing, Rows, Columns, Acquisition.Matrix, In.Plane.Phase.Encoding.Direction,
         DiffusionB.Value, Diffusion.Gradient.Orientation,
         Series.Number, Acquisition.Number, n.dcm.infolder, n.Instances,
         Sequence.Name, Image.Type,
         Img.Contrast, pred.Img.Contrast) 

# Save info in tsv/csv file
write.table(DF, 
            file = "/home/vlab/MS_proj/info_files/acquisition_info_zuyderland_withcontrasts.tsv", 
            sep='\t', row.names = FALSE, quote = TRUE)

# # Histogram per date with Scanner model
# ggplot(DF, aes(Study.Date, fill = as.factor(Manufacturer.Model.Name))) +
#   geom_histogram(breaks = seq(dmy("01-07-2007"), dmy("30-06-2019"), by = "6 months"), alpha = 0.5) +
#   scale_x_date(breaks = seq(dmy("01-07-2007"), dmy("30-06-2019"), by = "12 months"), 
#                date_labels = "%b %Y") +
#   theme_minimal() +
#   labs(x = "Acquisition date", y = "",
#        fill = "Machine Model") +
#   theme(legend.position = "top")







