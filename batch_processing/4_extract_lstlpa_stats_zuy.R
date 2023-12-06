#!/usr/bin/env Rscript

# Extract LST-lpa stats from zuyderland data
# Diana Giraldo, Nov 2023

# Inputs: 
# Directory with processed MRI
PRO_DIR = "/home/vlab/MS_proj/processed_MRI_zuy"
#File with session info and MRI processing pipeline
SESfile <- "/home/vlab/MS_proj/info_files/session_zuy_info.csv"

# Load session info
DS <- read.csv(SESfile, header = TRUE, colClasses = "character") %>%
  mutate(Date = as.Date(Date), t0 = as.Date(t0)) %>%
  filter(proc_pipe != "no_proc") %>%
  rename(zuy_pipe = proc_pipe) %>%
  mutate(proc_pipe = case_when(
    zuy_pipe == "HR_FLAIR_and_HR_T1W" ~ "CsT1",
    zuy_pipe == "HR_FLAIR" ~ "C",
    grepl("LR_FLAIR", zuy_pipe) ~ "A",
    TRUE ~ NA_character_
  ))

# Data frame with lesion stats from LST-lpa
thLST <- 0.1
DVOL <- data.frame()

for (pp in c("CsT1", "C", "A")) {
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
          file = "/home/vlab/MS_proj/feature_tables/lstlpa_outputs_zuy.csv", 
          row.names = FALSE)

rm(DS, DVOL, PRO_DIR, SESfile)