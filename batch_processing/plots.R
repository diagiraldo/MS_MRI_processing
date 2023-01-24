#!/usr/bin/env Rscript

# Extract SAMSEG stats per MRI processing protocol
# Diana Giraldo, Dec 2022

library(dplyr)
library(lubridate)

# Inputs: 
# Directory with processed MRI
PRO_DIR = "/home/vlab/MS_proj/processed_MRI"
#File with session info and MRI processing pipeline
SESfile <- "/home/vlab/MS_proj/info_files/session_MRIproc_pipeline.csv"

# Load session info
DS <- read.csv(SESfile, header = TRUE, colClasses = "character")

# Data frame with volume estimations from SAMSEG
DVOL <- data.frame()

for (pp in c("CsT1", "C", "B", "A")) {
  tmpDS <- filter(DS, proc_pipe == pp)
  for (i in 1:nrow(tmpDS)){
    subcode <- tmpDS$Subject[i]
    sesscode <- tmpDS$Session[i]
    cat(sprintf("Pipeline %s, Row %d, Subject: %s, Session: %s\n", pp, i, subcode, sesscode))
    inssfile <- sprintf("%s/sub-%s/ses-%s/anat/samseg/samseg.stats", PRO_DIR, subcode, sesscode)
    intivfile <- sprintf("%s/sub-%s/ses-%s/anat/samseg/sbtiv.stats", PRO_DIR, subcode, sesscode)
    if (file.exists(inssfile) & file.exists(intivfile)) {
      segvols <- read.table(inssfile, 
                            header = FALSE, sep = ",",  dec =".", comment.char = "") 
      tiv <- read.table(intivfile, 
                        header = FALSE, sep = ",",  dec =".", comment.char = "") 
      tmpvols <- rbind(segvols, tiv) 
      tmpdf <- as.data.frame(t(tmpvols$V2))
      names(tmpdf) <- make.names(gsub("# Measure ", "", tmpvols$V1))
      tmpdf <- tmpdf %>%
        mutate(Subject = subcode, Session = sesscode) %>%
        select(Subject, Session, everything())
      DVOL <- bind_rows(DVOL, tmpdf)
      rm(segvols, tiv, tmpvols,  tmpdf, inssfile, intivfile)
    }
  }
}

# Organize 
DVOL <- left_join(select(DS, Subject, Session, Date:proc_pipe), DVOL) %>%
  select(Subject, Session, Date:proc_pipe,
         Intra.Cranial, Lesions,
         ends_with("Cerebral.Cortex"), ends_with("Cerebral.White.Matter"),
         ends_with("Cerebellum.Cortex"), ends_with("Cerebellum.White.Matter"),
         ends_with("Amygdala"), ends_with("Hippocampus"),
         ends_with("Accumbens.area"), ends_with("Putamen"), ends_with("Pallidum"),
         ends_with("Caudate"), ends_with("Thalamus"),
         ends_with("choroid.plexus"), ends_with("VentralDC"),
         ends_with("Inf.Lat.Vent"), ends_with("Ventricle"), CSF, 
         Brain.Stem) %>%
  arrange(Subject, Session)

#####
DS <- DS %>%
  mutate(Date = as.Date(Date)) %>%
  left_join(., select(DVOL, Subject:Session, Month:Lesions)) %>%
  mutate(isproc = ifelse(!is.na(Intra.Cranial), "Yes", "No"))


# Plot histograms for session info
library(ggplot2)
ph <- ggplot(DS, aes(Date, fill = Sess.FLAIR.ACQ, colour = Sess.FLAIR.ACQ)) +
  geom_histogram(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "2 months"), alpha = 0.5) +
  scale_x_date(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "6 months"), 
               date_labels = "%b %Y") +
  theme_minimal() +
  labs(x = "Acquisition date", y = "",
       fill = "FLAIR acquisition", colour = "FLAIR acquisition") +
  theme(legend.position = "top")
ph

ggsave(filename = "/home/vlab/Dropbox/FLAIR_presentations/img/histogram_FLAIR_acq.png",
       ph, width = 24, height = 10, units = "cm", dpi = 300, bg = "transparent")

colorseq <- c("#2A3585", "#78207F", "#C7325D", "#FF8166")
ph <- ggplot(DS, aes(Date, fill = proc_pipe, colour = proc_pipe)) +
  geom_histogram(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "2 months"), alpha = 0.5) +
  scale_x_date(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "6 months"), 
               date_labels = "%b %Y") +
  theme_minimal() +
  labs(x = "Acquisition date", y = "",
       fill = "MRI Processing pipeline", colour = "MRI Processing pipeline") +
  theme(legend.position = "top") +
  scale_color_manual(values = colorseq) +
  scale_fill_manual(values = colorseq)
ph

ggsave(filename = "/home/vlab/Dropbox/FLAIR_presentations/img/histogram_MRIproc_pipeline.png",
       ph, width = 24, height = 10, units = "cm", dpi = 300, bg = "transparent")

colorseq <- c("#AED6F1", "#2E86C1")
ph <- ggplot(DS, aes(Date, fill = isproc, colour = isproc)) +
  geom_histogram(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "2 months"), alpha = 0.5) +
  scale_x_date(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "6 months"), 
               date_labels = "%b %Y") +
  theme_minimal() +
  labs(x = "Acquisition date", y = "",
       fill = "Is it already processed?", colour = "Is it already processed?") +
  theme(legend.position = "top") +
  scale_color_manual(values = colorseq) +
  scale_fill_manual(values = colorseq)
ph

ggsave(filename = "/home/vlab/Dropbox/FLAIR_presentations/img/histogram_MRIproc_ready.png",
       ph, width = 24, height = 10, units = "cm", dpi = 300, bg = "transparent")

# 

######
lsub <- unique(DS$Subject)

set.seed(2222)
idx <- sample(lsub, size = 20)
X <- filter(DS, !is.na(Intra.Cranial) & Subject %in% idx) 

colorseq <- c("#2A3585", "#78207F", "#C7325D", "#FF8166")
plt <- ggplot(X, aes(x = Date, y = Lesions, colour = proc_pipe)) +
  geom_line(aes(group = Subject), colour = "gray70", lwd = 0.5) +
  geom_point() +
  theme_minimal() +
  labs(x = "Acquisition date", y = "Lesion volume (mm^3)",
       colour = "MRI Processing pipeline") +
  theme(legend.position = "top") +
  scale_x_date(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "12 months"), 
               date_labels = "%b %Y") +
  scale_y_continuous(limits = c(0,10000))  +
  scale_color_manual(values = colorseq)
plt
ggsave(filename = "/home/vlab/Dropbox/FLAIR_presentations/img/example_traj_lesvol.png",
       plt, width = 24, height = 10, units = "cm", dpi = 300, bg = "transparent")
