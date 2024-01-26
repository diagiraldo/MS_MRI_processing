#################################
# load longCombat package
#################################
library(longCombat)
library(invgamma)
library(lme4)

#################################
# Get data
#################################
library("dplyr")
library("lubridate")

DF <- read.csv("~/MS_proj/feature_tables/MRI_features_18122023.csv",
               colClasses = "character") %>%
  select(OAZIS_PATID:MRIpipeline,
         samseg.Intra.Cranial, 
         ends_with(".normTIV"),
         -contains("Unknowns")) %>%
  mutate(across(samseg.Intra.Cranial:samseg.Ventricles.normTIV, as.numeric),
         MRIdate = as.Date(MRIdate),
         ID = as.factor(OAZIS_PATID), 
         MRIpipeline = as.factor(MRIpipeline)) %>%
  relocate(ID) %>%
  select(-OAZIS_PATID) %>%
  filter(!is.na(MRIpipeline))

vol_feat <- setdiff(names(DF), c("ID", "MRIdate", "MRIpipeline"))

# Transform MRI date into time variable IN MONTHS
DF <- DF %>%
  group_by(ID) %>%
  mutate(t0 = min(MRIdate),
         Month = round(time_length(interval(t0, MRIdate), "month"))) %>%
  select(-t0) %>%
  relocate(Month, .after = MRIdate) %>%
  as.data.frame(.)

# plot distributions of features
library("reshape2")
library("ggplot2")
X <- DF %>%
  melt(measure.vars = vol_feat)
pl = ggplot(X, aes(x = value, colour = MRIpipeline, fill = MRIpipeline)) +
  #geom_histogram(aes(y=..density..)) +
  geom_density(alpha=.2) +
  facet_wrap(vars(variable), nrow =6, scales = "free") +
  theme_bw()
pl

#################################
# batchTimeViz() -- visualize change in batch over time
#################################
batchTimeViz(batchvar='MRIpipeline',
             timevar='Month',
             data=DF)

#################################
# batchBoxplot() -- to visualize residuals across batches
# can do for each feature you are interested in
#################################
# make batch boxplot for selected feature, do not adjust for batch 
sel_feat = vol_feat[1]
batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline', 
             feature=sel_feat, 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4)

# make batch boxplot for selected feature, DO adjust for batch 
# order by increasing batch variance
# (centers boxplot means on the zero line)
batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline', 
             feature=sel_feat, 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             adjustBatch=TRUE,
             orderby='var',
             colors=1:4)

#################################
# trajPlot() -- visualize trajectories
#################################
# for everyone
trajPlot(idvar='ID', 
         timevar='Month',
         feature=sel_feat, 
         batchvar='MRIpipeline',  
         data=DF,
         point.col=DF$MRIpipeline)

#################################
# addTest() -- test for additive scanner effects
#################################
addTestTable <- addTest(idvar='ID', 
                        batchvar='MRIpipeline',  
                        features=vol_feat, 
                        formula='Month',
                        ranef='(1|ID)',
                        data=DF)

# check boxplot to see additive scanner effects
sel_feat <- vol_feat[as.numeric(rownames(addTestTable)[2])]
batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline',  
             feature=sel_feat, 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4,
             title=sel_feat)

# compare with another
sel_feat <- vol_feat[as.numeric(rownames(addTestTable)[41])]
batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline',  
             feature=sel_feat, 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4,
             title=sel_feat)

#################################
# multTest() -- test for multiplicative scanner effects
#################################
multTestTable <- multTest(idvar='ID', 
                          batchvar='MRIpipeline',  
                          features=vol_feat, 
                          formula='Month',
                          ranef='(1|ID)',
                          data=DF)

# check boxplot to see this
# (we will adjust for batch and order by variance
# to best see the multiplicative batch effects)
sel_feat <- vol_feat[as.numeric(rownames(multTestTable)[1])]
batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline',  
             feature=sel_feat, 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4,
             adjustBatch=TRUE,
             orderby='var',
             title=sel_feat)

# compare with another
sel_feat <- vol_feat[as.numeric(rownames(multTestTable)[40])]
batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline',  
             feature=sel_feat, 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4,
             adjustBatch=TRUE,
             orderby='var',
             title=sel_feat)

#################################
# longCombat() -- apply longitudinal ComBat
#################################