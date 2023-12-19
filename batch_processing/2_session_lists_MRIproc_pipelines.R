#!/usr/bin/env Rscript

# See protocol and define processing pipeline
# Diana Giraldo, Nov 2022

library(dplyr)
library(lubridate)

# Inputs: File with MRI info per subject and session
imgset <- "_2"
SESfile <- sprintf("/home/vlab/MS_proj/info_files/session_MRI_info%s.csv", imgset) 

# Load session info
DS <- read.csv(SESfile, header = TRUE, colClasses = "character") %>%
  mutate(Date = as.Date(Date))

# Define processing pipeline
DS <- DS %>%
  mutate(
    proc_pipe = case_when(
      (grepl("no GD", Sess.T1.ACQ) & grepl("C", Sess.FLAIR.ACQ)) ~ "CsT1",
      (!grepl("no GD", Sess.T1.ACQ) & grepl("C", Sess.FLAIR.ACQ)) ~ "C",
      grepl("B", Sess.FLAIR.ACQ) & Sess.n.FLAIR >= 3 ~ "B",
      grepl("A", Sess.FLAIR.ACQ) & Sess.n.FLAIR >= 2 ~ "A",
      TRUE ~ NA_character_
    )
  )

# Save text files with subject and date per pipeline
for (pp in c("CsT1", "C", "B", "A")){
  tmpD <- filter(DS, proc_pipe == pp) %>%
    mutate(Sess.str = paste(Subject, Session))
  outfile <- sprintf("/home/vlab/MS_proj/info_files/subject_date_proc_%s_%s.txt", pp, imgset)
  write.table(tmpD$Sess.str, file = outfile, row.names = FALSE, col.names = FALSE, quote = FALSE)
}
rm(tmpD, outfile, pp)

outfile <- sprintf("%s/session_MRIproc_pipeline_%s.csv", dirname(SESfile), imgset)
write.csv(DS, file = outfile, row.names = FALSE)

rm(DS, outfile, SESfile, imgset)
