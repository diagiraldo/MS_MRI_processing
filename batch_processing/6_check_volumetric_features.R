#################################
# Load libraries
#################################
library(dplyr)
library(lubridate)
library(ggplot2)

pipecolorseq <- c("#2A3585", "#78207F", "#C7325D", "#FF8166")

#################################
# Get data
#################################
# Pelt data
DP <- read.csv("/home/vlab/MS_proj/feature_tables/MRI_features_18122023.csv",
              header = TRUE, colClasses = "character") %>%
  filter(!is.na(MRIpipeline)) %>%
  mutate(MRIdate = as.Date(MRIdate),
         ID = as.factor(OAZIS_PATID), 
         MRIpipeline = as.factor(MRIpipeline),
         across(lstlpa.nLesions:samseg.Ventricles.normTIV, as.numeric),
         dataset = "PELT")

# Zuyderland data
DZ <- read.csv("/home/vlab/MS_proj/feature_tables/MRI_features_zuy_16112023.csv",
               header = TRUE, colClasses = "character") %>%
  mutate(MRIdate = as.Date(MRIdate),
         ID = as.factor(Subject), 
         MRIpipeline = as.factor(MRIpipeline),
         across(lstlpa.nLesions:samseg.Ventricles.normTIV, as.numeric),
         dataset = "ZUY")

#################################
# Check volumetric features
# Volumes in cm^3 = mL = 1000 mm^3 ~ 1000 voxels
#################################
feature_name <- "samseg.Left.Putamen"

A <- bind_rows(select(DP, ID, MRIdate, MRIpipeline, dataset, !!sym(feature_name)),
               select(DZ, ID, MRIdate, MRIpipeline, dataset, !!sym(feature_name))) %>%
  mutate(dataset = as.factor(dataset)) %>%
  group_by(ID) %>%
  mutate(t0 = min(MRIdate),
         Month = round(time_length(interval(t0, MRIdate), "month"))) %>%
  select(-t0)
  
# Plot histograms/distributions
ph <- ggplot(A, aes(x=!!sym(feature_name), color=MRIpipeline, fill = MRIpipeline)) +
  facet_grid(dataset ~ ., scales = "free_y") +
  geom_histogram(alpha=.2, position = "dodge") +
  #geom_density(alpha=.2) +
  theme_bw() +
  scale_color_manual(values = pipecolorseq) +
  scale_fill_manual(values = pipecolorseq)
ph

# Plot trajectories
pt <- ggplot(A, aes(x=Month, y = !!sym(feature_name))) +
  facet_wrap(~ dataset, ncol = 1, scales = "free_x") +
  geom_point(aes(color=MRIpipeline), size = 0.25, alpha = 0.75) +
  geom_line(aes(group = ID), colour = "gray70", lwd = 0.5, alpha = 0.75) +
  theme_bw() +
  scale_color_manual(values = pipecolorseq)
pt
  
  
