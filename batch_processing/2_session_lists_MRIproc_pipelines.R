#!/usr/bin/env Rscript

# See protocol and define processing pipeline
# Diana Giraldo, Nov 2022

library(dplyr)
library(lubridate)

# Inputs: File with MRI info per subject and session
SESfile <- "/home/vlab/MS_proj/info_files/session_MRI_info.csv"
SUBfile <- "/home/vlab/MS_proj/info_files/subject_MRI_info.csv"

# Load session info
DS <- read.csv(SESfile, header = TRUE, colClasses = "character")

# Define processing pipeline
DS <- DS %>%
  mutate(Date = as.Date(Date),
         proc_pipe = ifelse(Sess.T1.ACQ == "no GD" & grepl("C", Sess.FLAIR.ACQ), "CsT1",
                            ifelse(grepl("C", Sess.FLAIR.ACQ), "C", 
                                   ifelse(grepl("B", Sess.FLAIR.ACQ), "B", 
                                          ifelse(grepl("A", Sess.FLAIR.ACQ), "A", NA)))))

# Plot histograms for session info
library(ggplot2)
ph <- ggplot(DS, aes(Date, fill = proc_pipe, colour = proc_pipe)) +
  geom_histogram(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "2 months"), alpha = 0.5) +
  scale_x_date(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "6 months"), 
               date_labels = "%b %Y") +
  theme_minimal() +
  labs(x = "Acquisition date", y = "",
       fill = "MRI Processing pipeline", colour = "MRI Processing pipeline") +
  theme(legend.position = "top")
ph

# Save text files with subject and date per pipeline
for (pp in c("CsT1", "C", "B", "A")){
  tmpD <- filter(DS, proc_pipe == pp) %>%
    mutate(Sess.str = paste(Subject, Session))
  outfile <- sprintf("/home/vlab/MS_proj/info_files/subject_date_proc_%s.txt", pp)
  write.table(tmpD$Sess.str, file = outfile, row.names = FALSE, col.names = FALSE, quote = FALSE)
}

