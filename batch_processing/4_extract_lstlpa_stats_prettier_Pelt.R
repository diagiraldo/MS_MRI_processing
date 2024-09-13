#!/usr/bin/env Rscript

# Extract LST estimations of volume after aplying prettier to Pelt data
# Diana Giraldo, Sept 2024
# Last update: Sept 2024

library(dplyr)
library(lubridate)

thLST <- 0.1

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
      if (pp %in% c("B", "A")){
        inlstfile <- sprintf("%s/sub-%s/ses-%s/anat/prettier_LST/LST_lpa_%0.1f.csv", PRO_DIR, subcode, sesscode, thLST)
      } else {
        inlstfile <- sprintf("%s/sub-%s/ses-%s/anat/LST/LST_lpa_%0.1f.csv", PRO_DIR, subcode, sesscode, thLST)
      }
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
    mutate(proc_pipe = ifelse(!is.na(lstlpa.Lesion.Volume), proc_pipe, NA),
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
          file = sprintf("/home/vlab/MS_proj/feature_tables/lstlpa_outputs_prettier_Pelt_%s.csv", timestr), 
          row.names = FALSE)


rm(DS, DF, PRO_DIR, SESfile)