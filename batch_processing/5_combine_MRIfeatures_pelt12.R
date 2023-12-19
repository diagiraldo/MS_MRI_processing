#!/usr/bin/env Rscript

# Combine features all Pelt data
# Diana Giraldo, Dec 2023

library(dplyr)
library(lubridate)

timestr <- format(Sys.Date(), "%d%m%Y")

# Read features Set 1
imgset <- ""
infile <- sprintf("/home/vlab/MS_proj/feature_tables/MRI_features%s_%s.csv", imgset, timestr)
S1 <- read.csv(infile, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         Set = 1) 

# Read features Set 2
imgset <- "_2"
infile <- sprintf("/home/vlab/MS_proj/feature_tables/MRI_features%s_%s.csv", imgset, timestr)
S2 <- read.csv(infile, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         Set = 2) 

rm(imgset, infile)

# Bind two sets according to dates, (it is possible that the same session is in both sets >= 4 sessions)
DF <- bind_rows(S1,S2)
rm(S1,S2)

# Get t0 and Month
DF <- DF %>%
  group_by(Subject.folder) %>%
  mutate(t0 = min(MRIdate),
         Month = round(time_length(interval(t0, MRIdate), "month"))) %>%
  arrange(t0, MRIdate)


# Table per subject
DU <- DF %>%
  group_by(Subject.folder) %>%
  summarise(First.sess = min(MRIdate),
            Last.sess = max(MRIdate),
            Last.month = max(Month),
            n.sess = length(unique(MRIdate)),
            n.MRIpipelines = length(unique(MRIpipeline)),
            MRIpipelines = paste(sort(unique(MRIpipeline)), collapse = ", "),
            Sets = paste(sort(unique(Set)), collapse = ", ")) %>%
  arrange(First.sess)

# Save
write.csv(DF, 
          file = sprintf("/home/vlab/MS_proj/feature_tables/MRI_features_pelt12_%s.csv", timestr), 
          row.names = FALSE)

write.csv(DU, 
          file = sprintf("/home/vlab/MS_proj/feature_tables/Subjects_pelt12_%s.csv", timestr), 
          row.names = FALSE)

rm(DU,DF,timestr)