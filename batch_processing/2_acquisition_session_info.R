#!/usr/bin/env Rscript

#  Info per session
# Diana Giraldo, Nov 2022

library(dplyr)
library(lubridate)

# Input: File with acquisition info
imgset <- "_2"
acqfile <- sprintf("/home/vlab/MS_proj/MS_MRI%s/acquisition_info_anat.tsv", imgset)

# Outputs:
# File with MRI acquisition info
MRIfile <- sprintf("/home/vlab/MS_proj/info_files/anat_MRI_info%s.csv", imgset)
# File with MRI info per session
SESfile <- sprintf("/home/vlab/MS_proj/info_files/session_MRI_info%s.csv", imgset)
# File with info per subject
SUBfile <- sprintf("/home/vlab/MS_proj/info_files/subject_MRI_info%s.csv", imgset)

# Read table with acquisition info
DF <- read.table(acqfile, sep = "\t", header = TRUE, colClasses = "character") %>%
  mutate(across(c(Slice.Thickness, Spacing.Between.Slices, 
                  Repetition.Time, Echo.Time, Inversion.Time), 
                as.numeric),
         Date = ymd(as.Date(Instance.Creation.Date)))

DF <- DF %>%
  # Identify FLAIR acquisition protocols
  mutate(FLAIR.A = (Inversion.Time > 0 & Slice.Thickness == 5 & Spacing.Between.Slices == 6),
         FLAIR.B = (Inversion.Time > 0 & Slice.Thickness == 3 & Spacing.Between.Slices == 3),
         FLAIR.C = (Inversion.Time > 0 & Slice.Thickness == 1.2 & Spacing.Between.Slices == 0.6)) %>%
  mutate(FLAIR.ACQ = case_when( FLAIR.A ~ "A",
                                FLAIR.B ~ "B",
                                FLAIR.C ~ "C",
                                TRUE ~ NA_character_)) %>%
  # Identify HR structural T1 without/with contrast (GD)
  mutate(T1.noGD = (Repetition.Time < 20 & Echo.Time < 20 &
                      Slice.Thickness <= 1 & Spacing.Between.Slices <= 1 &
                      !grepl("GD|GADO", Series.Description, ignore.case = TRUE)),
         T1.GD = (Repetition.Time < 20 & Echo.Time < 20 &
                      Slice.Thickness <= 1 & Spacing.Between.Slices <= 1 &
                      grepl("GD|GADO", Series.Description, ignore.case = TRUE))) %>%
  mutate(T1.ACQ = case_when( T1.noGD ~ "no GD",
                             T1.GD ~ "with GD",
                             TRUE ~ NA_character_)) %>%
  # Slice Cross-talk
  mutate(Slice.Crosstalk = ifelse(MR.Acquisition.Type == "3D", 0,
                                  Slice.Thickness/Spacing.Between.Slices))

# Table per session
DS <- DF %>%
  group_by(Subject, Session) %>%
  summarise(Sess.FLAIR.ACQ = paste(sort(unique(FLAIR.ACQ)), collapse = ", "),
            Sess.n.FLAIR = sum(!is.na(FLAIR.ACQ)),
            Sess.T1.ACQ = paste(sort(unique(T1.ACQ)), collapse = ", "), 
            Date = unique(Date)) %>%
  group_by(Subject) %>%
  mutate(t0 = min(Date),
         Month = round(time_length(interval(t0, Date), "month")))

# Table per subject
DU <- DS %>%
  group_by(Subject) %>%
  summarise(First.sess = min(Date),
            Last.sess = max(Date),
            n.sess = n(),
            n.FLAIR.ACQ = length(unique(Sess.FLAIR.ACQ))) %>%
  arrange(First.sess)

# Save info
write.csv(DF, file = MRIfile, row.names = FALSE)
write.csv(DS, file = SESfile, row.names = FALSE)
write.csv(DU, file = SUBfile, row.names = FALSE)

# # Plot histograms for session info
# library(ggplot2)
# 
# ph <- ggplot(DS, aes(Date, fill = Sess.FLAIR.ACQ, colour = Sess.FLAIR.ACQ)) +
#   geom_histogram(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "2 months"), alpha = 0.5) +
#   scale_x_date(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "6 months"), 
#                date_labels = "%b %Y") +
#   theme_minimal() +
#   labs(x = "Acquisition date", y = "",
#        fill = "FLAIR acquisition", colour = "FLAIR acquisition") +
#   theme(legend.position = "top")
# 
# ggsave(filename = sprintf("%s/histogram_FLAIR_acq.png", dirname(MRIfile)),
#        ph, width = 24, height = 12, units = "cm", dpi = 300, bg = "transparent")
# 
# ggsave(filename = "/home/vlab/Dropbox/FLAIR_presentations/img/histogram_FLAIR_acq.png",
#        ph, width = 24, height = 10, units = "cm", dpi = 300, bg = "transparent")
# 
# # tmpDS <- DS %>%
# #   arrange(t0) 
# # tmpDS$Subject <- factor(tmpDS$Subject, levels = unique(tmpDS$Subject))
# # 
# # ggplot(tmpDS, aes(x = Date, y = Subject, colour = Sess.FLAIR.ACQ, group = Subject)) +
# #   theme_minimal() + 
# #   geom_point(size = 0.5) +
# #   labs(x = "Acquisition date", y = "Subject",
# #        colour = "FLAIR acquisition") +
# #   theme(legend.position = "top")
