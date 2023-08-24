#!/usr/bin/env Rscript

# Read acquisition duration and create table
# Diana Giraldo, April 2023

library(dplyr)
library(stringr)

# Directory with acquisition info files
INFO_DIR = "/home/vlab/MS_proj/tmp_acq_duration"

# File with DICOM tags
dcmtags_file <- "/home/vlab/MS_MRI_processing/data/dicomtags.csv"
dcmtags <- read.csv(dcmtags_file)
  
# List of files
flist <- list.files(path = INFO_DIR, full.names = FALSE)

DF <- data.frame()
# Read each file 
for (i in 1:length(flist)) {
  # file info
  subcode <- strsplit(flist[i],"_")[[1]][1]
  prevfolder <- strsplit(flist[i],"_")[[1]][2]
  dcminfo_file <- paste(INFO_DIR, flist[i], sep = "/")
  linfo <- read.delim(dcminfo_file, header = FALSE) %>%
    mutate(tag = str_extract(V1, "(?<=\\[)(.*?)(?=\\])"),
           value = trimws(str_extract(V1, "(?<=\\] )(.*)"), "right")) %>%
    select(-V1) %>%
    unique(.) %>%
    left_join(., dcmtags, by = "tag")
  linfo$Keyword[linfo$tag == "2001,1085"] <- "MRSeriesMagneticFieldStrength"
  linfo$Keyword[linfo$tag == "2001,100B"] <- "SliceOrientation"
  # Reshape
  info <- linfo$value
  names(info) <- make.names(linfo$Keyword, unique = TRUE)
  info <- as.data.frame(t(info)) %>%
    mutate(Subject = subcode,
           PrevFolder = prevfolder)
 DF <- bind_rows(DF, info)
}

# File with MRI acquisition info
MRIfile <- "/home/vlab/MS_proj/info_files/anat_MRI_info.csv"
FLinfo <- read.csv(MRIfile, header = TRUE, colClasses = "character") %>%
  filter(as.logical(FLAIR.A) | as.logical(FLAIR.B) | as.logical(FLAIR.C)) 

A <- left_join(FLinfo, unique(select(DF, -PrevFolder))) %>%
  mutate(Acquisition.Duration = as.numeric(Acquisition.Duration))

# Plot histograms for with acquisition duration
library(ggplot2)

ph <- ggplot(A, aes(Acquisition.Duration, fill = FLAIR.ACQ, colour = FLAIR.ACQ)) +
  geom_histogram(breaks = seq(150, 240, by = 10), alpha = 0.5) 
ph




