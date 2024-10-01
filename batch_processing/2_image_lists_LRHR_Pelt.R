#!/usr/bin/env Rscript

# Session with LR and HR FLAIR in Pelt
# Diana Giraldo, Sept 2024

library(dplyr)
library(lubridate)
library(tidyr)

# Read first set
MRIfiles <- c("/home/vlab/MS_proj/info_files/anat_MRI_info.csv",
              "/home/vlab/MS_proj/info_files/anat_MRI_info_2.csv")
              
M <- data.frame()
for(Set in seq_along(MRIfiles)){
  S <- read.csv(MRIfiles[Set], header = TRUE, colClasses = "character") %>%
    filter(!is.na(FLAIR.ACQ)) %>%
    mutate(across(c(Slice.Thickness, Spacing.Between.Slices, 
                    Repetition.Time, Echo.Time, Inversion.Time), 
                  as.numeric),
           Date = ymd(as.Date(Instance.Creation.Date)),
           Set = Set)
  M <- bind_rows(M,S)
}      
rm(S, Set)

# Table per session
DS <- M %>%
  group_by(Subject, Session) %>%
  summarise(Sess.FLAIR.ACQ = paste(sort(unique(FLAIR.ACQ)), collapse = ", "),
            Sess.n.FLAIR = sum(!is.na(FLAIR.ACQ)),
            Date = unique(Date)) %>%
  filter(grepl("C", Sess.FLAIR.ACQ) & grepl("A|B",  Sess.FLAIR.ACQ)) %>%
  mutate(LRHRFLAIR = TRUE)

# Filter FLAIR images in those sessions
M <- left_join(M, DS) %>%
  filter(LRHRFLAIR) %>%
  select(Subject, Session, File.basename, InfoName,
         MR.Acquisition.Type:Inversion.Time, Spacing.Between.Slices, Pixel.Spacing,
         Protocol.Name, SliceOrientation, 
         Date, Set, Sess.FLAIR.ACQ, Sess.n.FLAIR, LRHRFLAIR) %>%
  mutate(folder = ifelse(Set == 1, "processed_MRI", "MS_MRI_2"),
         bn = ifelse(Set == 1, File.basename, InfoName), 
         res = ifelse(Spacing.Between.Slices <= 1, "HR", "LR"),
         sf = ifelse(res == "HR", "", as.character(round(Spacing.Between.Slices))),
         Img.str = paste(Subject, Session, bn, folder, res, sf))
  

outfile <- "/home/vlab/MS_proj/info_files/list_LRHR_FLAIR.txt"
write.table(M$Img.str, file = outfile, row.names = FALSE, col.names = FALSE, quote = FALSE)

