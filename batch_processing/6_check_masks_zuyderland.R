library(dplyr)
library(lubridate)

# Calculated features
A <- read.csv("/home/vlab/MS_proj/feature_tables/MRI_features_zuy_16112023.csv", 
              header = TRUE, colClasses = "character") %>%
  select(Subject:MRIpipeline,
         contains(c("Cerebral.Cortex", "Cerebral.GMCortex")))

# Missing GM 
M <- read.csv("/home/vlab/MS_proj/info_files/missing_gm_zuy.csv", 
              header = TRUE) %>%
  mutate(Subject = gsub("sub-", "", Subject),
         Session = gsub("ses-", "", Session),
         miss.gm = TRUE) %>%
  select(Subject, Session, miss.gm)

# Sesion info
DS <- read.csv("/home/vlab/MS_proj/info_files/session_zuy_info.csv", 
               header = TRUE, colClasses = "character") %>%
  left_join(., A) %>%
  left_join(., M)

