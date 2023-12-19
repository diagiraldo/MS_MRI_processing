#!/usr/bin/env Rscript

# Extract SAMSEG stats per MRI processing protocol
# Diana Giraldo, Dec 2022
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

# Data frame with volume estimations from SAMSEG
DVOL <- data.frame()

for (pp in c("CsT1", "C", "B", "A")) {
  tmpDS <- filter(DS, proc_pipe == pp)
  for (i in 1:nrow(tmpDS)){
    subcode <- tmpDS$Subject[i]
    sesscode <- tmpDS$Session[i]
    # cat(sprintf("Pipeline %s, Row %d, Subject: %s, Session: %s\n", pp, i, subcode, sesscode))
    inssfile <- sprintf("%s/sub-%s/ses-%s/anat/samseg/samseg.stats", PRO_DIR, subcode, sesscode)
    intivfile <- sprintf("%s/sub-%s/ses-%s/anat/samseg/sbtiv.stats", PRO_DIR, subcode, sesscode)
    inunkfile <- sprintf("%s/sub-%s/ses-%s/anat/samseg/count_unknownswithinbrain.txt", PRO_DIR, subcode, sesscode)
    if (file.exists(inssfile) & file.exists(intivfile) & file.exists(inunkfile)) {
      segvols <- read.table(inssfile, 
                            header = FALSE, sep = ",",  dec =".", comment.char = "") 
      tiv <- read.table(intivfile, 
                        header = FALSE, sep = ",",  dec =".", comment.char = "") 
      count_unknowns <- read.table(inunkfile)$V1
      tmpvols <- rbind(segvols, tiv) 
      tmpdf <- as.data.frame(t(tmpvols$V2))
      names(tmpdf) <- make.names(paste0("samseg.", gsub("# Measure ", "", tmpvols$V1)))
      tmpdf <- tmpdf %>%
        mutate(Subject = subcode, Session = sesscode) %>%
        select(Subject, Session, everything()) %>%
        mutate(samseg.Unknowns = count_unknowns)
      DVOL <- bind_rows(DVOL, tmpdf)
      rm(segvols, tiv, tmpvols,  tmpdf, inssfile, intivfile, inunkfile, count_unknowns)
    }
  }
}
rm(tmpDS, i, pp, subcode, sesscode)

# Organize SAMSEG estimation of volumes (in mm^3)
DVOL <- left_join(select(DS, Subject, Session, Date:proc_pipe), DVOL) %>%
  select(Subject, Session, Date:proc_pipe,
         samseg.Intra.Cranial, samseg.Lesions,
         ends_with("Cerebral.Cortex"), ends_with("Cerebral.White.Matter"),
         ends_with("Cerebellum.Cortex"), ends_with("Cerebellum.White.Matter"),
         ends_with("Amygdala"), ends_with("Hippocampus"),
         ends_with("Accumbens.area"), ends_with("Putamen"), ends_with("Pallidum"),
         ends_with("Caudate"), ends_with("Thalamus"),
         ends_with("choroid.plexus"), ends_with("VentralDC"),
         ends_with("Inf.Lat.Vent"), ends_with("Ventricle"), 
         samseg.CSF, samseg.Brain.Stem, samseg.Unknowns) %>%
  arrange(Subject, Session)

# Indicate which ones were not processed
DVOL <- DVOL %>%
  mutate(proc_pipe = ifelse(!is.na(samseg.Intra.Cranial), proc_pipe, NA)) 

# Save info
write.csv(DVOL, 
          file = sprintf("/home/vlab/MS_proj/feature_tables/samseg_outputs%s.csv", imgset), 
          row.names = FALSE)

rm(DS, DVOL, PRO_DIR, SESfile)







