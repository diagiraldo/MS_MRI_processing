library(dplyr)
library(lubridate)
library(ggplot2)

# Input: File with acquisition info
acqfile <- "/home/vlab/MS_proj/info_files/acquisition_info_zuyderland_withcontrasts.tsv"

# File with MRI acquisition info
MRIfile <- "/home/vlab/MS_proj/info_files/FLAIR_HRT1W_zuy_info.csv"
# File with MRI info per session
SESfile <- "/home/vlab/MS_proj/info_files/session_zuy_info.csv"

# Read table with info extracted from DICOMS
DF <- read.table(acqfile, sep = "\t", header = TRUE, colClasses = "character") %>%
  mutate(across(c(Slice.Thickness, Spacing.Between.Slices, 
                  Repetition.Time, Echo.Time, Inversion.Time,
                  n.dcm.infolder, n.Instances,
                  DiffusionB.Value), 
                as.numeric),
         Study.Date = ymd(as.Date(Study.Date)))

# Acquisition resolutions for FLAIR and identification of HR T1W-MRI
DF <- DF %>%
  mutate(FLAIR.ACQ = case_when(
    (Slice.Thickness <= 1 & MR.Acquisition.Type == "3D") ~ "HR", # C
    (Slice.Thickness == 3 & Spacing.Between.Slices == 3) ~ "LR_3mm", # B
    (Slice.Thickness == 3 & Spacing.Between.Slices == 3.9) ~ "LR_3.9mm", 
    (Slice.Thickness == 4 & Spacing.Between.Slices == 4.4) ~ "LR_4.4mm", 
    (Slice.Thickness == 4 & Spacing.Between.Slices == 5.2) ~ "LR_5.2mm", 
    (Slice.Thickness == 5 & Spacing.Between.Slices == 5.5) ~ "LR_5.5mm", 
    (Slice.Thickness == 5 & Spacing.Between.Slices == 6) ~ "LR_6mm", # A
    (Slice.Thickness == 5 & Spacing.Between.Slices == 6.5) ~ "LR_6.5mm",
    (Slice.Thickness == 5 & Spacing.Between.Slices == 1.5) ~ "LR_6.5mm",
    (Slice.Thickness == 5 & Spacing.Between.Slices == 7) ~ "LR_7mm",
    TRUE ~ NA_character_
  )) %>%
  mutate(FLAIR.ACQ = ifelse(pred.Img.Contrast == "FLAIR", FLAIR.ACQ, NA)) %>%
  mutate(T1.HR = (pred.Img.Contrast == "T1W" & Slice.Thickness <= 1 & MR.Acquisition.Type == "3D")) %>%
  # Slice Cross-talk
  mutate(Slice.Crosstalk = ifelse(MR.Acquisition.Type == "3D", 0,
                                  Slice.Thickness/Spacing.Between.Slices)) %>%
  filter((pred.Img.Contrast == "FLAIR") | ( pred.Img.Contrast == "T1W" & T1.HR)) 

# Table per session
DS <- DF %>%
  group_by(Subject, Session) %>%
  summarise(Sess.n.HRFLAIR = sum(!is.na(FLAIR.ACQ) & FLAIR.ACQ == "HR"),
            Sess.n.LRFLAIR = sum(grepl("LR", FLAIR.ACQ)),
            Sess.FLAIR.ACQ = paste(sort(unique(FLAIR.ACQ)), collapse = ", "),
            Sess.n.HRT1 = sum(T1.HR), 
            Sess.n.LRT1 = sum(pred.Img.Contrast == "T1W" & !T1.HR),
            #Machine = unique(Manufacturer.Model.Name),
            Date = ymd(as.Date(unique(Study.Date)))) %>%
  group_by(Subject) %>%
  mutate(t0 = min(Date),
         Month = round(time_length(interval(t0, Date), "month"))) %>%
  mutate(acqgroup = case_when(
    (Sess.n.HRFLAIR + Sess.n.LRFLAIR == 0) ~ "no FLAIR",
    (Sess.n.HRFLAIR == 0 & Sess.n.LRFLAIR > 0 & Sess.n.HRT1 == 0) ~ paste(Sess.n.LRFLAIR, "LR FLAIR"),
    (Sess.n.HRFLAIR == 0 & Sess.n.LRFLAIR > 0 & Sess.n.HRT1 >= 1) ~ paste(Sess.n.LRFLAIR, "LR FLAIR and HR T1W"),
    (Sess.n.HRFLAIR > 0 & Sess.n.HRT1 == 0) ~ "HR FLAIR",
    (Sess.n.HRFLAIR > 0 & Sess.n.HRT1 >= 1) ~ "HR FLAIR and HR T1W",
    TRUE ~ NA_character_
  )) %>%
  # Define processing pipeline
  mutate(proc_pipe = case_when(
    (Sess.n.HRFLAIR == 0 & Sess.n.LRFLAIR <= 1) ~ "no_proc",
    (Sess.n.HRFLAIR == 0 & Sess.n.LRFLAIR >= 2 & Sess.n.HRT1 == 0) ~ "LR_FLAIR",
    (Sess.n.HRFLAIR >= 1 & Sess.n.HRT1 == 0) ~ "HR_FLAIR",
    (Sess.n.HRFLAIR == 0 & Sess.n.LRFLAIR >= 2 & Sess.n.HRT1 >= 1) ~ "LR_FLAIR_and_HR_T1W",
    (Sess.n.HRFLAIR >= 1 & Sess.n.HRT1 >= 0) ~ "HR_FLAIR_and_HR_T1W",
    TRUE ~ NA_character_
  ))

DF <- left_join(DF, DS)

# Save DF and DS
write.csv(DF, file = MRIfile, row.names = FALSE)
write.csv(DS, file = SESfile, row.names = FALSE)

###############################################################################
# Indicate images to process

# Include LR flair if proc pipe use them
SI <- filter(DF, grepl("LR_FLAIR", proc_pipe) & grepl("LR_", FLAIR.ACQ))
# Inclue 1 HR FLAIR
tmp <- filter(DF, proc_pipe == "HR_FLAIR" & FLAIR.ACQ == "HR") %>%
  group_by(Subject, Session) %>%
  arrange(desc(n.Instances)) %>%
  slice(1)
SI <- bind_rows(SI, tmp)
tmp <- filter(DF, proc_pipe == "HR_FLAIR_and_HR_T1W" & FLAIR.ACQ == "HR")
SI <- bind_rows(SI, tmp)
# Include first HR T1W 
tmp <- filter(DF, grepl("HR_T1W", proc_pipe) & T1.HR) %>%
  group_by(Subject, Session) %>%
  arrange(Series.Time) %>%
  slice(1)
SI <- bind_rows(SI, tmp)

# Write lists for processing pipelines
for (pp in c("LR_FLAIR", "LR_FLAIR_and_HR_T1W", "HR_FLAIR", "HR_FLAIR_and_HR_T1W")){
  tmpD <- filter(SI, proc_pipe == pp) %>%
    mutate(Sess.str = paste(Subject, Session, FolderName, pred.Img.Contrast))
  outfile <- sprintf("/home/vlab/MS_proj/info_files/imgs_zuy_proc_%s.txt", pp)
  write.table(tmpD$Sess.str, file = outfile, row.names = FALSE, col.names = FALSE, quote = FALSE)
}

for (pp in c("LR_FLAIR", "HR_FLAIR")){
  tmpD <- filter(DS, grepl(pp, proc_pipe)) %>%
    mutate(Sess.str = paste(Subject, Session))
  write.table(tmpD$Sess.str, 
              file = sprintf("/home/vlab/MS_proj/info_files/sessions_zuy_proc_%s.txt", pp), 
              row.names = FALSE, col.names = FALSE, quote = FALSE)
}

##### No procesessed yet, to be processed with prettier
pp <- "no_proc"

SI <- filter(DF, grepl(pp, proc_pipe)) %>%
  filter(!is.na(FLAIR.ACQ)) %>%
  mutate(Sess.str = paste(Subject, Session, FolderName, pred.Img.Contrast))
outfile <- sprintf("/home/vlab/MS_proj/info_files/imgs_zuy_proc_%s.txt", pp)
write.table(SI$Sess.str, file = outfile, row.names = FALSE, col.names = FALSE, quote = FALSE)  

tmpD <- filter(DS, grepl(pp, proc_pipe)) %>%
  mutate(Sess.str = paste(Subject, Session))
write.table(tmpD$Sess.str, 
            file = sprintf("/home/vlab/MS_proj/info_files/sessions_zuy_proc_%s.txt", pp), 
            row.names = FALSE, col.names = FALSE, quote = FALSE)

# Plot histograms for session info
library(ggplot2)

ph <- ggplot(DS, aes(Date, fill = acqgroup, colour = acqgroup)) +
  geom_histogram(breaks = seq(dmy("01-07-2007"), dmy("30-06-2019"), by = "6 months"), alpha = 0.5) +
  scale_x_date(breaks = seq(dmy("01-07-2007"), dmy("30-06-2019"), by = "12 months"), 
               date_labels = "%b %Y") +
  theme_minimal() +
  labs(x = "Acquisition date", y = "",
       fill = "FLAIR acquisition", colour = "FLAIR acquisition") +
  theme(legend.position = "top")
ph

ggsave(filename = "/home/vlab/MS_proj/info_files/histogram_acq_zuyderland.png",
       ph, width = 24, height = 10, units = "cm", dpi = 300, bg = "white")

# Check sessions 
y <- filter(DS, acqgroup == "1 LR FLAIR and HR T1W")

i=2
x <- filter(DF, Subject == y$Subject[i] & Session == y$Session[i])
x