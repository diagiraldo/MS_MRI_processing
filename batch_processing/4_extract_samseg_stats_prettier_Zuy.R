#!/usr/bin/env Rscript

# Extract SAMSEG estimations of volume after applying prettier to ZMC data
# Diana Giraldo, Sept 2024
# Last update: Sept 2024

library(dplyr)
library(lubridate)

# Directory with processed MRI
PRO_DIR = "/home/vlab/MS_proj/processed_MRI_zuy"
#File with session info and MRI processing pipeline
SESfile <- "/home/vlab/MS_proj/info_files/session_zuy_info.csv"

# Load session info
DS <- read.csv(SESfile, header = TRUE, colClasses = "character") %>%
  mutate(Date = as.Date(Date)) %>%
  select(-t0, -Month) %>%
  rename(zuy_pipe = proc_pipe) %>%
  mutate(proc_pipe = case_when(
    zuy_pipe == "HR_FLAIR_and_HR_T1W" ~ "CsT1",
    zuy_pipe == "HR_FLAIR" ~ "C",
    grepl("LR_FLAIR", zuy_pipe) ~ "A",
    TRUE ~ "D"
  ))

DVOL <- data.frame()

for (pp in c("LR_FLAIR", "HR_FLAIR", "no_proc")){ 
  tmpDS <- filter(DS, grepl(pp, zuy_pipe))
  for (i in 1:nrow(tmpDS)){
    subcode <- tmpDS$Subject[i]
    sesscode <- tmpDS$Session[i]
    
    ssfname = ifelse(pp %in% c("LR_FLAIR", "no_proc"), "prettier_samseg", "samseg")
    inssfile <- sprintf("%s/sub-%s/ses-%s/anat/%s/samseg.stats", PRO_DIR, subcode, sesscode, ssfname)
    intivfile <- sprintf("%s/sub-%s/ses-%s/anat/%s/sbtiv.stats", PRO_DIR, subcode, sesscode, ssfname)
    inunkfile <- sprintf("%s/sub-%s/ses-%s/anat/%s/count_unknownswithinbrain.txt", PRO_DIR, subcode, sesscode, ssfname)
    
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

rm(tmpDS, i, pp, subcode, sesscode, ssfname, inssfile, intivfile, inunkfile)

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

# Get t0 and Month
DVOL <- DVOL %>%
  mutate(Subject.folder = sprintf("sub-%s", Subject),
         Session.folder = sprintf("ses-%d", as.numeric(Session))) %>%
  rename(ID = Subject, MRIdate = Date, MRIpipeline = proc_pipe) %>%
  group_by(Subject.folder) %>%
  mutate(t0 = min(MRIdate),
         Month = round(time_length(interval(t0, MRIdate), "month"))) %>%
  arrange(ID, MRIdate)

# Save info
timestr <- format(Sys.Date(), "%d%m%Y")
write.csv(DVOL, 
          file = sprintf("/home/vlab/MS_proj/feature_tables/samseg_outputs_prettier_ZMC_%s.csv", timestr), 
          row.names = FALSE)

rm(DS, DVOL, PRO_DIR, SESfile, timestr)