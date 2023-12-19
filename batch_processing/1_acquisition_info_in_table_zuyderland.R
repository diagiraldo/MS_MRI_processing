#!/usr/bin/env Rscript

# Read acquisition info in .json files and save a table with
# all acqusition info.
# Diana Giraldo, Nov 2023

suppressMessages(library(dplyr))
suppressMessages(library(jsonlite))

args = commandArgs(trailingOnly=TRUE)

# Inputs
# Directory with acquisition info files
ACQ_DIR = args[1]
# ACQ_DIR = "/mnt/extradata/MRI_Zuyderland/acquisition_info"
# ACQ_DIR = "/mnt/extradata/MSPELT_2/remaining_acquisition_info"
# Output
out_file = args[2] 

# List of subjects
sublist <- list.dirs(path = ACQ_DIR, 
                     recursive = FALSE, full.names = FALSE)

# Init data frame
DF <- data.frame()

for (subcode in sublist){
  print(sprintf("Subject: %s", subcode))
  subdir <- paste(ACQ_DIR, subcode, sep = "/")
  sesslist <- list.dirs(path = subdir, 
                        recursive = FALSE, full.names = FALSE)
  for (sesscode in sesslist){
    sessdir <- paste(subdir, sesscode, sep = "/")
    # Data frame per session
    sessdf <- data.frame()
    filelist <- list.files(path = sessdir, pattern = "\\.json$")
    for (imgi in 1:length(filelist)){
      filebn <- gsub(".json", "", filelist[imgi])
      injson <- paste(sessdir, filelist[imgi], sep = "/")
      tmp <- fromJSON(injson, flatten = TRUE)
      tmp <- lapply(tmp, function(x) ifelse(is.null(x), "", x))
      tmp <- as.data.frame(tmp) %>%
        mutate(Subject = subcode,
               Session = sesscode,
               InfoName = filebn) %>%
        select(Subject, Session, InfoName, everything())
      names(tmp) <- make.names(names(tmp))
      sessdf <- bind_rows(sessdf, tmp)
      rm(tmp)
    }
    DF <- bind_rows(DF,sessdf)
  }
}

# Save info in tsv/csv file
write.table(DF, file = out_file, sep='\t', row.names = FALSE, quote = TRUE)

# Read with
# read.table(outtsv, sep = "\t", header = TRUE, colClasses = "character")