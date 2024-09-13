library(dplyr)
library(lubridate)

inNX <- "/home/vlab/MS_proj/feature_tables/MRI_features_prettier_Pelt_13092024.csv"
inX <- "/home/vlab/MS_proj/feature_tables/MRI_features_pelt12_18122023.csv"

NX <- read.csv(inNX, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         SR = ifelse(MRIpipeline %in% c("A", "B"), "prettier", NA)) %>%
  select(-Session)

X <- read.csv(inX, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         SR = ifelse(MRIpipeline %in% c("A", "B"), "mbSRR", NA))

DF <- bind_rows(NX,X) %>%
  mutate(ID = as.factor(Subject.folder))

library(ggplot2)

plt <- ggplot(filter(DF, !is.na(MRIpipeline)), 
              aes(x = samseg.Lesions, y = lstlpa.Lesion.Volume, colour = MRIpipeline)) +
  facet_wrap(.~SR) + 
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", size = 0.75, colour = "gray70") +
  geom_point(size = 0.5) +
  geom_smooth(method = lm, se = FALSE, size = 0.75) +
  theme_minimal() +
  labs(x = "Lesion Volume - SAMSEG estimation", y = "Lesion Volume - LST-lpa estimation",
       colour = "MRI Processing pipeline") +
  theme(legend.position = "top") +
  scale_color_manual(values = c("#2A3585", "#78207F", "#C7325D", "#FF8166"))


ggplot(filter(DF, MRIpipeline %in% c("A", "B")), 
       aes(x = lstlpa.Lesion.Volume, colour = MRIpipeline)) +
  facet_grid(SR~.) +
  geom_histogram() +
  xlim(0,50)

# Plot trajectories
pipecolorseq <- c("#2A3585", "#78207F", "#C7325D", "#FF8166")

feature_name <- "samseg.CSF.normTIV"
pt <- ggplot(filter(DF, MRIpipeline %in% c("A", "B")), 
             aes(x=Month, y = !!sym(feature_name))) +
  facet_wrap(~ SR, ncol = 1, scales = "free_x") +
  geom_point(aes(color=MRIpipeline), size = 0.25, alpha = 0.75) +
  geom_line(aes(group = ID), colour = "gray70", lwd = 0.5, alpha = 0.75) +
  theme_bw() +
  scale_color_manual(values = pipecolorseq)
pt