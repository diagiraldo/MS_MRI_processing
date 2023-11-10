#!/usr/bin/env Rscript

# convert DICOM info (extracted with dcminfo) into .json
# Diana Giraldo, Nov 2022

suppressMessages(library(dplyr))
suppressMessages(library(stringr))
suppressMessages(library(jsonlite))

args = commandArgs(trailingOnly=TRUE)

# Inputs
dcminfo_file <- args[1]
dcmtags_file <- args[2]
# Output
json_file <- args[3]

if ( file.size(dcminfo_file) > 0 ){
  # Read DICOM tags names
  dcmtags <- read.csv(dcmtags_file)
  # Read image info
  linfo <- read.delim(dcminfo_file, header = FALSE) %>%
    mutate(tag = str_extract(V1, "(?<=\\[)(.*?)(?=\\])"),
           value = trimws(str_extract(V1, "(?<=\\] )(.*)"), "right")) %>%
    select(-V1) %>%
    unique(.) %>%
    left_join(., dcmtags, by = "tag") %>%
    mutate(Keyword = ifelse(tag == "2001,100B", "SliceOrientation", Keyword),
           Keyword = ifelse(tag == "2005,102A", "MRPatientReferenceID", Keyword))
  # Reshape
  info <- linfo$value
  names(info) <- linfo$Keyword
  info <- as.list(info)
  # Convert to JSON
  jj <- toJSON(x = info, pretty = T, auto_unbox = TRUE)
  write(jj, json_file)
} else {
  sprintf("No info in file %s", dcminfo_file)
}





