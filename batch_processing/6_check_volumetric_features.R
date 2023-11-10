library(dplyr)
library(lubridate)
library(ggplot2)

A <- read.csv("/home/vlab/MS_proj/feature_tables/MRI_features_13092023.csv", header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         ver = "after") %>%
  filter(!is.na(MRIpipeline))

B <- read.csv("/home/vlab/MS_proj/feature_tables/MRI_features_25012023.csv", header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         ver = "before") %>%
  filter(!is.na(MRIpipeline))

feat <- "lstlpa.Lesion.Volume"

DIFF <- right_join(select(B, OAZIS_PATID:MRIpipeline, !!sym(feat)),
                   select(A, OAZIS_PATID:MRIpipeline, !!sym(feat)),
                   by = names(A)[1:4],
                   suffix = c(".before", ".after")) %>%
  mutate(diff = !!sym(paste0(feat,".after")) - !!sym(paste0(feat,".before")))

pl <- ggplot(DIFF, aes(x=MRIpipeline, y=diff)) + geom_point(size = 0.5) 
pl

DF <- bind_rows(B, A) %>%
  mutate(IDSESS = paste(OAZIS_PATID, MRIdate, sep = "_"),
         ver = factor(ver, levels = c("before", "after")))

pl <- ggplot(DF, aes(x = samseg.Lesions, y = lstlpa.Lesion.Volume, colour = MRIpipeline)) +
  facet_wrap(.~ver) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", size = 0.75, colour = "gray70") +
  geom_point(size = 0.5) +
  geom_smooth(method = lm, se = FALSE, size = 0.75) +
  theme_minimal() +
  labs(x = "Lesion Volume - SAMSEG estimation", y = "Lesion Volume - LST-lpa estimation",
       colour = "MRI Processing pipeline") +
  theme(legend.position = "top") +
  scale_color_manual(values = c("#2A3585", "#78207F", "#C7325D", "#FF8166"))
pl

# Check Trajectories
lsub <- unique(DF$OAZIS_PATID)
colorseq <- c("#2A3585", "#78207F", "#C7325D", "#FF8166")

feat <- "samseg.Intra.Cranial"

set.seed(2222)
idx <- sample(lsub, size = 149)
X <- filter(DF, OAZIS_PATID %in% idx) 

plt <- ggplot(X, aes(x = MRIdate, y = !!sym(feat), colour = MRIpipeline)) +
  facet_grid(ver ~ .) +
  geom_point(size = 0.25, alpha = 0.75) +
  geom_line(aes(group = OAZIS_PATID), colour = "gray70", lwd = 0.5, alpha = 0.75) +
  #geom_smooth(aes(group = OAZIS_PATID), method = lm, se = FALSE, size = 0.5, colour = "gray70") +
  theme_minimal() +
  labs(x = "Acquisition date", y = "Intracranial volume (mL)",
       colour = "MRI Processing pipeline") +
  theme(legend.position = "top") +
  scale_x_date(breaks = seq(dmy("01-01-2011"), dmy("31-12-2017"), by = "12 months"), 
               date_labels = "%b %Y") +
  scale_y_continuous(limits = c(1100,1800))  +
  scale_color_manual(values = colorseq)
plt


idx <- lsub[1]
tmp <- filter(DF, OAZIS_PATID == idx) %>%
  group_by(ver) %>%
  do(model = lm(samseg.Intra.Cranial ~ MRIdate, data = .))
  
  
