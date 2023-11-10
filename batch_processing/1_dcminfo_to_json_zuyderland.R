#!/usr/bin/env Rscript

# convert DICOM info (extracted with dcminfo) into .json
# Diana Giraldo, Nov 2023

suppressMessages(library(dplyr))
suppressMessages(library(stringr))
suppressMessages(library(jsonlite))
suppressMessages(library(reshape2))

args = commandArgs(trailingOnly=TRUE)

# Inputs
ACQ_DIR = args[1]
#ACQ_DIR = "/mnt/extradata/MRI_Zuyderland/acquisition_info"
dcmtags_file <- args[2]
#dcmtags_file <- "/home/vlab/MS_MRI_processing/data/dicomtags.csv"

# Read DICOM tags names
dcmtags <- read.csv(dcmtags_file)

# List of subjects
sublist <- list.dirs(path = ACQ_DIR, 
                     recursive = FALSE, full.names = FALSE)

for (subcode in sublist){
  #print(sprintf("Subject: %s", subcode))
  subdir <- paste(ACQ_DIR, subcode, sep = "/")
  sesslist <- list.dirs(path = subdir, 
                        recursive = FALSE, full.names = FALSE)
  for (sesscode in sesslist){
    #print(sprintf("  Session: %s", sesscode))
    sessdir <- paste(subdir, sesscode, sep = "/")
    folderlist <- list.dirs(path = sessdir, 
                            recursive = FALSE, full.names = FALSE)
    for (foldercode in folderlist){
      folderdir <- paste(sessdir, foldercode, sep = "/")
      filelist <- list.files(path = folderdir, pattern = "\\.txt$")
      ndcm <- length(filelist)
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
          names(info) <- make.names(linfo$Keyword)
          # In tmpdf
          tmpdf <- bind_rows(tmpdf, info)
        } else {
          print(sprintf("No info in file %s", dcminfo_file))
        }
      }
      df <- tmpdf %>% 
        mutate(n.dcm.infolder = ndcm) %>%
        select(-any_of(c("Image.Position.Patient", "Image.Orientation.Patient", 
                         "Acquisition.Time", "Content.Time", "Instance.Number"))) %>% unique() %>%
        mutate(Start.Time = min(tmpdf$Acquisition.Time),
               End.Time = max(tmpdf$Acquisition.Time),
               n.Instances = max(as.numeric(tmpdf$Instance.Number)))
      for (i in 1:nrow(df)){
        jj <- toJSON(x = as.list(df[i,]), pretty = T, auto_unbox = TRUE)
        json_file <- paste0(paste(sessdir, paste(foldercode, i, sep = "_"), sep = "/"), ".json")
        write(jj, json_file)
        print(sprintf("file %s created", json_file))
      }
    }
  }
}

# subcode <- "zuy-005"
# subdir <- paste(ACQ_DIR, subcode, sep = "/")
# sesslist <- list.dirs(path = subdir,
#                       recursive = FALSE, full.names = FALSE)
# 
# sesscode <- "20150127"
# sessdir <- paste(subdir, sesscode, sep = "/")
# folderlist <- list.dirs(path = sessdir,
#                         recursive = FALSE, full.names = FALSE)
# 
# foldercode <- "00001FE0"
# folderdir <- paste(sessdir, foldercode, sep = "/")
# filelist <- list.files(path = folderdir, pattern = "\\.txt$")
