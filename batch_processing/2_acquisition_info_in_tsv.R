#!/usr/bin/env Rscript

# Read acquisition info in .json files
# Diana Giraldo, Nov 2022

library(jsonlite)
library(dplyr)

# Directory with (organized) images and acquisition info files
MRI_DIR = "/home/vlab/MS_proj/MS_MRI"

# Init data frame
DF <- data.frame()

# List of cases/subjects
sublist <- list.dirs(path = MRI_DIR, 
                     recursive = FALSE, full.names = FALSE)

# Loop over subjects
for (subi in 1:length(sublist)) {
  subcode <- gsub("sub-", "", sublist[subi])
  fullsubdir <- paste(MRI_DIR, sublist[subi], sep = "/")
  sesslist <- list.dirs(path = fullsubdir, 
                        recursive = FALSE, full.names = FALSE)
  # Data frame per subject
  subdf <- data.frame()
  # Loop over sessions
  for (sesi in 1:length(sesslist)){
    sescode <- gsub("ses-", "", sesslist[sesi])
    fullsesdir <- paste(fullsubdir, sesslist[sesi], sep = "/")
    fullimgdir <- paste(fullsesdir, "anat", sep = "/")
    filelist <- list.files(path = fullimgdir, pattern = "\\.json$")
    # Data frame per session
    sessdf <- data.frame()
    # Loop over images in anat directory
    for (imgi in 1:length(filelist)){
      filebn <- gsub(".json", "", filelist[imgi])
      injson <- paste(fullimgdir, filelist[imgi], sep = "/")
      tmp <- as.data.frame(fromJSON(injson, flatten = TRUE)) %>%
        mutate(Subject = subcode,
               Session = sescode,
               File.basename = filebn) %>%
        select(Subject, Session, File.basename, everything())
      names(tmp) <- make.names(names(tmp))
      sessdf <- bind_rows(sessdf, tmp)
      rm(tmp)
    }
    subdf <- bind_rows(subdf, sessdf)
    rm(sessdf)
  }
  DF <- bind_rows(DF,subdf)
}

# Save info in tsv file
outtsv <- paste(MRI_DIR, "acquisition_info_anat.tsv", sep = "/")
write.table(DF, file = outtsv, sep='\t', row.names = FALSE, quote = TRUE)

# Read with
# read.table(outtsv, sep = "\t", header = TRUE, colClasses = "character")







