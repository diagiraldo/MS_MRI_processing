#!/usr/bin/env Rscript

# convert DICOM info (extracted with dcminfo) into .json
# Diana Giraldo, Dec 2023

suppressMessages(library(dplyr))
suppressMessages(library(stringr))
suppressMessages(library(jsonlite))
suppressMessages(library(reshape2))

args = commandArgs(trailingOnly=TRUE)

# Inputs
ACQ_DIR = args[1]
# ACQ_DIR = "/mnt/extradata/MSPELT_2/remaining_acquisition_info"
dcmtags_file <- args[2]
#dcmtags_file <- "/home/vlab/MS_MRI_processing/data/dicomtags.csv"

# Read DICOM tags names
dcmtags <- read.csv(dcmtags_file)

# Function that reads all dicominfo files in a folder and writes one (or more) .json files
write_acqinfo_json <- function(folderdir){
  filelist <- list.files(path = folderdir, pattern = "\\.txt$")
  ndcm <- length(filelist)
  # info from all dicoms in one data.frame
  tmpdf <- data.frame()
  for (filenam in filelist){
    dcminfo_file <- paste(folderdir, filenam, sep = "/")
    if ( file.size(dcminfo_file) > 0 ){
      linfo <- read.delim(dcminfo_file, header = FALSE) %>%
        mutate(tag = str_extract(V1, "(?<=\\[)(.*?)(?=\\])"),
               value = trimws(str_extract(V1, "(?<=\\] )(.*)"), "right")) %>%
        select(-V1) %>%
        unique(.) %>%
        left_join(., dcmtags, by = "tag") %>%
        mutate(Keyword = ifelse(tag == "2001,100B", "SliceOrientation", Keyword),
               Keyword = ifelse(tag == "2005,102A", "MRPatientReferenceID", Keyword)) %>%
        select(Keyword, value) 
      # Reshape
      info <- as.data.frame(t(linfo$value))
      names(info) <- make.names(linfo$Keyword, unique = TRUE)
      rm(linfo)
      tmpdf <- bind_rows(tmpdf, info)
      rm(info)
    } else {
      print(sprintf("No info in file %s", dcminfo_file))
    }
  }
  # Unique acq info in dicom folder
  df <- tmpdf %>% 
    mutate(n.dcm.infolder = ndcm) %>%
    select(-any_of(c("Image.Position.Patient", "Image.Orientation.Patient", 
                     "Acquisition.Time", "Content.Time", "Rows.1", "Columns.1")),
           -starts_with(c("Instance.Number"))) %>% unique() %>%
    mutate(Start.Time = min(tmpdf$Acquisition.Time),
           End.Time = max(tmpdf$Acquisition.Time),
           n.Instances = max(max(as.numeric(tmpdf$Instance.Number.1)), 
                             max(as.numeric(tmpdf$Instance.Number))))
  rm(tmpdf)
  # Write .json(s)
  sessdir <- dirname(folderdir)
  foldercode <- basename(folderdir)
  for (i in 1:nrow(df)){
    jj <- toJSON(x = as.list(df[i,]), pretty = T, auto_unbox = TRUE)
    json_file <- paste0(paste(sessdir, paste(foldercode, i, sep = "_info"), sep = "/"), ".json")
    write(jj, json_file)
    print(sprintf("file %s created", json_file))
  }
  return(invisible(NULL))
}

#####################
# Execute in all folders

# List of subjects
sublist <- list.dirs(path = ACQ_DIR, 
                     recursive = FALSE, full.names = FALSE)

for (subcode in sublist){
  subdir <- paste(ACQ_DIR, subcode, sep = "/")
  sesslist <- list.dirs(path = subdir, 
                        recursive = FALSE, full.names = FALSE)
  for (sesscode in sesslist){
    sessdir <- paste(subdir, sesscode, sep = "/")
    folderlist <- list.dirs(path = sessdir, 
                            recursive = FALSE, full.names = FALSE)
    for (foldercode in folderlist){
      folderdir <- paste(sessdir, foldercode, sep = "/")
      write_acqinfo_json(folderdir)
    }
  }
}

