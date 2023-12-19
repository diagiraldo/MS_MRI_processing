#!/usr/bin/env Rscript

# Infor per session for all Pelt data
# Diana Giraldo, Dec 2023

library(dplyr)
library(lubridate)
library(tidyr)

# Read first set
imgset = ""
SESfile <- sprintf("/home/vlab/MS_proj/info_files/session_MRI_info%s.csv", imgset)

S1 <- read.csv(SESfile, header = TRUE, colClasses = "character") %>%
  mutate(Date = as.Date(Date),
         Set = 1) %>%
  rename_with(~ gsub(".ACQ", ".ACQ.1", .x), ends_with(".ACQ")) %>%
  select(-t0, -Month)

# Read second set
imgset = "_2"
SESfile <- sprintf("/home/vlab/MS_proj/info_files/session_MRI_info%s.csv", imgset)

S2 <- read.csv(SESfile, header = TRUE, colClasses = "character") %>%
  mutate(Date = as.Date(Date))  %>%
  rename_with(~ gsub(".ACQ", ".ACQ.2", .x), ends_with(".ACQ"))%>%
  select(-t0, -Month)

# Merge two sets according to dates, (it is possible that the same session is in both sets >= 4 sessions)
All <- full_join(S1, S2) %>%
  mutate(Set = ifelse(is.na(Set), 2, Set)) %>%
  unite("Sess.FLAIR.ACQ", starts_with("Sess.FLAIR.ACQ"), na.rm = TRUE, remove = TRUE, sep = ", ") %>%
  unite("Sess.T1.ACQ", starts_with("Sess.T1.ACQ"), na.rm = TRUE, remove = TRUE, sep = ", ") %>%
  select(Subject, Session, Date, Set, Sess.FLAIR.ACQ, Sess.T1.ACQ) 


# Get processing pipelines and Month after first session
All <- All %>%
  mutate(
    proc_pipe = case_when(
      (grepl("no GD", Sess.T1.ACQ) & grepl("C", Sess.FLAIR.ACQ)) ~ "CsT1",
      (!grepl("no GD", Sess.T1.ACQ) & grepl("C", Sess.FLAIR.ACQ)) ~ "C",
      grepl("B", Sess.FLAIR.ACQ) ~ "B",
      grepl("A", Sess.FLAIR.ACQ) ~ "A",
      TRUE ~ NA_character_
    ) 
  ) %>%
  group_by(Subject) %>%
  mutate(t0 = min(Date),
         Month = round(time_length(interval(t0, Date), "month"))) %>%
  arrange(t0, Date)

# Table per subject
DU <- All %>%
  group_by(Subject) %>%
  summarise(First.sess = min(Date),
            Last.sess = max(Date),
            Last.month = max(Month),
            n.sess = length(unique(Date)),
            n.proc_pipe = length(unique(proc_pipe)),
            proc_pipe = paste(sort(unique(proc_pipe)), collapse = ", "),
            Sets = paste(sort(unique(Set)), collapse = ", ")) %>%
  arrange(First.sess)
