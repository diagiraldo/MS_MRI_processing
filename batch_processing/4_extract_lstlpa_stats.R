#!/usr/bin/env Rscript

# Extract LST estimations of volume
# Diana Giraldo, January 2023
# Last update: Dec 2023

library(dplyr)
library(lubridate)

# Inputs: 
imgset <- "_2"

# Directory with processed MRI
PRO_DIR = ifelse(imgset == "_2",
                 "/home/vlab/MS_proj/MS_MRI_2",
                 "/home/vlab/MS_proj/processed_MRI")

#File with session info and MRI processing pipeline
SESfile <- sprintf("/home/vlab/MS_proj/info_files/session_MRIproc_pipeline_%s.csv", imgset) 

# Load session info
DS <- read.csv(SESfile, header = TRUE, colClasses = "character") %>%
  mutate(Date = as.Date(Date)) %>%
  select(-t0, -Month)

# Data frame with lesion stats from LST-lpa
thLST <- 0.1
DVOL <- data.frame()

for (pp in c("CsT1", "C", "B", "A")) {
  tmpDS <- filter(DS, proc_pipe == pp)
  for (i in 1:nrow(tmpDS)){
    subcode <- tmpDS$Subject[i]
    sesscode <- tmpDS$Session[i]
    inlstfile <- sprintf("%s/sub-%s/ses-%s/anat/LST/LST_lpa_%0.1f.csv", PRO_DIR, subcode, sesscode, thLST)
    if (file.exists(inlstfile)) {
      tmpdf <- read.table(inlstfile,
                          header = TRUE, sep = ",",  dec =".", comment.char = "") %>%
        select(TLV, N) %>%
        rename(lstlpa.Lesion.Volume = TLV, lstlpa.nLesions = N) %>%
        mutate(Subject = subcode, Session = sesscode) %>%
        select(Subject, Session, everything())
      DVOL <- bind_rows(DVOL, tmpdf)
      rm(tmpdf, inlstfile)
    }
  }
}
rm(tmpDS, i, pp, subcode, sesscode)

DVOL <- left_join(select(DS, Subject, Session, Date:proc_pipe), DVOL) %>%
  select(Subject, Session, Date:proc_pipe, everything()) %>%
  arrange(Subject, Session) %>%
  mutate(proc_pipe = ifelse(!is.na(lstlpa.Lesion.Volume), proc_pipe, NA))

# Save info
write.csv(DVOL, 
          file = sprintf("/home/vlab/MS_proj/feature_tables/lstlpa_outputs%s.csv", imgset), 
          row.names = FALSE)

rm(DS, DVOL, PRO_DIR, SESfile)
