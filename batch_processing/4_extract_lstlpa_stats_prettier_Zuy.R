#!/usr/bin/env Rscript

# Extract LST estimations of volume after applying prettier to ZMC data
# Diana Giraldo, Sept 2024
# Last update: Sept 2024

library(dplyr)
library(lubridate)

thLST <- 0.1

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
    if (pp %in% c("LR_FLAIR", "no_proc")){
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
          file = sprintf("/home/vlab/MS_proj/feature_tables/lstlpa_outputs_prettier_ZMC_%s.csv", timestr), 
          row.names = FALSE)

rm(DS, PRO_DIR, SESfile, DVOL, inlstfile, thLST, timestr)


