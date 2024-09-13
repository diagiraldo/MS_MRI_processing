#!/usr/bin/env Rscript

# Extract SAMSEG stats after applying prettier to Pelt data
# Diana Giraldo, Sept 2024
# Last update: Sept 2024

library(dplyr)
library(lubridate)

imgset_str = c("", "__2")
DF <- data.frame()

for (ss in c(1,2)){
  imgset = imgset_str[ss]
  # Directory with processed MRI
  PRO_DIR = ifelse(imgset == "__2",
                   "/home/vlab/MS_proj/MS_MRI_2",
                   "/home/vlab/MS_proj/processed_MRI")
  
  #File with session info and MRI processing pipeline
  SESfile <- sprintf("/home/vlab/MS_proj/info_files/session_MRIproc_pipeline%s.csv", imgset) 
  # Load session info
  DS <- read.csv(SESfile, header = TRUE, colClasses = "character") %>%
    mutate(Date = as.Date(Date)) %>%
    select(-t0, -Month)
  
  # Data frame with lesion stats from LST-lpa
  DVOL <- data.frame()
  for (pp in c("CsT1", "C", "B", "A")) {
    tmpDS <- filter(DS, proc_pipe == pp)
    for (i in 1:nrow(tmpDS)){
      subcode <- tmpDS$Subject[i]
      sesscode <- tmpDS$Session[i]
      ssfname = ifelse(pp %in% c("B", "A"), "prettier_samseg", "samseg")
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
    arrange(Subject, Session) %>%
    mutate(proc_pipe = ifelse(!is.na(samseg.Intra.Cranial), proc_pipe, NA),
           Set = ss) 
  
  DF <- bind_rows(DF, DVOL)
  rm(DVOL)
}

# Get t0 and Month
DF <- DF %>%
  mutate(Subject.folder = sprintf("sub-%07d", as.numeric(Subject)),
         Session.folder = sprintf("ses-%d", as.numeric(Session))) %>%
  rename(OAZIS_PATID = Subject, MRIdate = Date, MRIpipeline = proc_pipe) %>%
  group_by(Subject.folder) %>%
  mutate(t0 = min(MRIdate),
         Month = round(time_length(interval(t0, MRIdate), "month"))) %>%
  arrange(t0, MRIdate)

# Save info
timestr <- format(Sys.Date(), "%d%m%Y")
write.csv(DF, 
          file = sprintf("/home/vlab/MS_proj/feature_tables/samseg_outputs_prettier_Pelt_%s.csv", timestr), 
          row.names = FALSE)

rm(DS, DF, PRO_DIR, SESfile)