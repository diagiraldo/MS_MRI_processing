library(dplyr)
library(lubridate)
library(ggplot2)
library(reshape2)

pX <- "/home/vlab/MS_proj/feature_tables/MRI_features_prettier_ZMC_20092024.csv"
mX <- "/home/vlab/MS_proj/feature_tables/MRI_features_zuy_16112023.csv"

NX <- read.csv(pX, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         SR = ifelse(MRIpipeline %in% c("A", "B", "D"), "prettier", NA)) %>%
  select(-Session)

X <- read.csv(mX, header = TRUE) %>%
  mutate(MRIdate = as.Date(MRIdate),
         Subject.folder = sprintf("sub-%s", Subject),
         Session.folder = sprintf("ses-%d", as.numeric(Session)),
         SR = ifelse(MRIpipeline %in% c("A", "B"), "mbSRR", NA))

DF <- bind_rows(NX,X) %>%
  mutate(ID = as.factor(Subject.folder))

# 
A <- DF %>%
  select(Subject.folder, Session.folder, MRIpipeline, SR) %>%
  group_by(Subject.folder, Session.folder) %>%
  summarise(has_prettier = ifelse(any(SR == "prettier"), "True", "False"),
            has_mbsrr = ifelse(any(SR == "mbSRR"), "True", "False"))
  

# Plots
pipecolorseq <- c("#2A3585", "#78207F", "#C7325D", "#FF8166")

plt <- ggplot(DF, 
              aes(x = samseg.Lesions, y = lstlpa.Lesion.Volume, colour = MRIpipeline)) +
  facet_wrap(.~SR) + 
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", linewidth = 0.5, colour = "gray70") +
  geom_point(size = 0.5) +
  geom_smooth(method = lm, se = FALSE, linewidth = 0.75) +
  theme_minimal() +
  labs(x = "Lesion Volume - SAMSEG estimation", y = "Lesion Volume - LST-lpa estimation",
       colour = "MRI Processing pipeline") +
  theme(legend.position = "top") +
  scale_color_manual(values = pipecolorseq)
plt

# Plot Histogram 
feat_names <- names(DF)[10:93]

i <-2
feature_name <- feat_names[i]
ggplot(filter(DF, MRIpipeline %in% c("A", "B", "D")), 
       aes(x = !!sym(feature_name), colour = MRIpipeline, fill = MRIpipeline)) +
  facet_grid(SR~.) +
  geom_histogram(alpha = 0.5)

# Plot trajectories

pt <- ggplot(filter(DF, MRIpipeline %in% c("A", "B", "D")), 
             aes(x=Month, y = !!sym(feature_name))) +
  facet_wrap(~ SR, ncol = 1) +
  geom_point(aes(color=MRIpipeline), size = 0.25, alpha = 0.75) +
  geom_line(aes(group = ID), colour = "gray70", lwd = 0.5, alpha = 0.75) +
  theme_bw() +
  scale_color_manual(values = pipecolorseq)
pt

# Comparison mbSRR Vs Prettier
i <-5

feature_name <- feat_names[i]
C <- DF %>%
  #filter(MRIpipeline %in% c("A", "B")) %>%
  select(Subject.folder, Session.folder, MRIpipeline, SR, !!sym(feature_name)) %>%
  rename(value = !!sym(feature_name)) %>%
  filter(!is.na(SR)) %>%
  dcast(Subject.folder + Session.folder + MRIpipeline ~ SR)

ggplot(C, 
       aes(x = mbSRR, y = prettier, colour = MRIpipeline)) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", size = 0.75, colour = "gray70") +
  geom_point(size = 0.5) +
  geom_smooth(method = lm, se = FALSE, linewidth = 0.75) +
  theme_minimal() +
  labs(title = feature_name,
       x = "mbSRR estimation", y = "PRETTIER estimation",
       colour = "MRI Processing pipeline") +
  theme(legend.position = "bottom") +
  scale_color_manual(values = pipecolorseq)