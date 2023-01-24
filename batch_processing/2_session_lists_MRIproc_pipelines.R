#!/usr/bin/env Rscript

# See protocol and define processing pipeline
# Diana Giraldo, Nov 2022

library(dplyr)
library(lubridate)

# Inputs: File with MRI info per subject and session
SESfile <- "/home/vlab/MS_proj/info_files/session_MRI_info.csv"

# Load session info
DS <- read.csv(SESfile, header = TRUE, colClasses = "character")

# Define processing pipeline
DS <- DS %>%
  mutate(Date = as.Date(Date),
         proc_pipe = ifelse(Sess.T1.ACQ == "no GD" & grepl("C", Sess.FLAIR.ACQ), "CsT1",
                            ifelse(grepl("C", Sess.FLAIR.ACQ), "C", 
                                   ifelse(grepl("B", Sess.FLAIR.ACQ), "B", 
                                          ifelse(grepl("A", Sess.FLAIR.ACQ), "A", NA)))))

# Save text files with subject and date per pipeline
for (pp in c("CsT1", "C", "B", "A")){
  tmpD <- filter(DS, proc_pipe == pp) %>%
    mutate(Sess.str = paste(Subject, Session))
  outfile <- sprintf("/home/vlab/MS_proj/info_files/subject_date_proc_%s.txt", pp)
  write.table(tmpD$Sess.str, file = outfile, row.names = FALSE, col.names = FALSE, quote = FALSE)
}
rm(tmpD, outfile, pp)

outfile <- sprintf("%s/session_MRIproc_pipeline.csv", dirname(SESfile))
write.csv(DS, file = outfile, row.names = FALSE)

rm(DS, ph, outfile, SESfile)
