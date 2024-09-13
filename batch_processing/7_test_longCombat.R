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

fixed_effects = 'Month'
random_effects = '(1|ID)'
batch_variable = 'MRIpipeline'

batchBoxplot(idvar='ID', 
             batchvar=batch_variable, 
             feature=sel_feat, 
             formula=fixed_effects,
             ranef=random_effects,
             data=DF,
             colors=1:4)

# make batch boxplot for selected feature, DO adjust for batch 
# order by increasing batch variance
# (centers boxplot means on the zero line)
batchBoxplot(idvar='ID', 
             batchvar=batch_variable, 
             feature=sel_feat, 
             formula=fixed_effects,
             ranef=random_effects,
             data=DF,
             adjustBatch=TRUE,
             orderby='var',
             colors=1:4)

# fit linear mixed effect model
# # without batch
# lme_formula <- as.formula(paste0(sel_feat, '~', fixed_effects, '+' , random_effects))

# with batch
lme_formula <- as.formula(paste0(sel_feat, '~', fixed_effects, '+' , batch_variable, '+', random_effects))

lme_fit <- lme4::lmer(lme_formula, data=DF, REML=TRUE, control=lme4::lmerControl(optimizer='bobyqa'))

# residuals
fit_residuals <- data.frame(residuals=residuals(lme_fit), batch=DF[,batch_variable])
fit_residuals_means <- aggregate(fit_residuals$residuals, by=list(fit_residuals$batch), FUN=mean)
fit_residuals_var <- aggregate(fit_residuals$residuals, by=list(fit_residuals$batch), FUN=var)

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
fixed_effects = 'Month'
random_effects = '(1|ID)'
batch_variable = 'MRIpipeline'

DF_combat <- longCombat(idvar='ID', 
                        timevar='Month',
                        batchvar=batch_variable,  
                        features=vol_feat, 
                        formula=fixed_effects,
                        ranef=random_effects,
                        data=DF)

DF_harmon <- DF_combat$data_combat
vol_feat_combat <- paste(vol_feat, "combat", sep = ".")
DF <- merge(DF, DF_harmon)

###############################################################################
# longCombat() -- Step-by-step

batch <- droplevels(as.factor(DF[[batch_variable]]))
# number of batches
m <- nlevels(batch)
# row IDs for each batch 
batches <- lapply(levels(batch), function(x) which(batch==x))
# number of observations for each batch
ni <- sapply(batches, length)

featurenames <- vol_feat
# number of features
V <- length(featurenames)

# total number of observations
L <- nrow(DF)

###############################################################################


###############################################################################
# plot distributions
X <- DF %>%
melt(measure.vars = vol_feat_combat)
pl = ggplot(X, aes(x = value, colour = MRIpipeline, fill = MRIpipeline)) +
  geom_density(alpha=.2) +
  facet_wrap(vars(variable), nrow =6, scales = "free") +
  theme_bw()
pl
rm(X)

#################################
# test for additive scanner effects in combatted data
#################################
addTestTableCombat <- addTest(idvar='ID', 
                              batchvar='MRIpipeline',  
                              features=vol_feat_combat, 
                              formula='Month',
                              ranef='(1|ID)',
                              data=DF)

# Compare p-values
boxplot(-log(as.numeric(addTestTable$`KR p-value`), base=10),
        -log(as.numeric(addTestTableCombat$`KR p-value`), base=10),
        las=1,
        ylab='additive batch effect -log10(p-value)',
        names=c('before ComBat', 'after ComBat'))

# check boxplot before/after combat
sel_feat <- vol_feat[as.numeric(rownames(addTestTable)[2])]
batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline',  
             feature=sel_feat, 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4,
             title=paste(sel_feat, " before combat"))

batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline',  
             feature=paste(sel_feat, "combat", sep = "."), 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4,
             title=paste(sel_feat, " after combat"))

#################################
# test for multiplicative scanner effects in combatted data
#################################
multTestTableCombat <- multTest(idvar='ID', 
                                batchvar='MRIpipeline',  
                                features=vol_feat_combat, 
                                formula='Month',
                                ranef='(1|ID)',
                                data=DF)

# Compare p-values
boxplot(-log(as.numeric(multTestTable$`p-value`), base=10),
        -log(as.numeric(multTestTableCombat$`p-value`), base=10),
        las=1,
        ylab='multiplicative batch effect -log10(p-value)',
        names=c('before ComBat', 'after ComBat'))

# check boxplot before/after combat
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
             title=paste(sel_feat, " before combat"))

batchBoxplot(idvar='ID', 
             batchvar='MRIpipeline',  
             feature=paste(sel_feat, "combat", sep = "."), 
             formula='Month',
             ranef='(1|ID)',
             data=DF,
             colors=1:4,
             adjustBatch=TRUE,
             orderby='var',
             title=paste(sel_feat, " after combat"))

#################################
# plot trajectories before and after combat
#################################
sel_feat = vol_feat[39]
trajPlot(idvar='ID', 
         timevar='Month',
         feature=sel_feat, 
         batchvar='MRIpipeline',  
         data=DF,
         point.col=DF$MRIpipeline,
         title=paste(sel_feat, " before combat"))

trajPlot(idvar='ID', 
         timevar='Month',
         feature=paste(sel_feat, "combat", sep = "."), 
         batchvar='MRIpipeline',  
         data=DF,
         point.col=DF$MRIpipeline,
         title=paste(sel_feat, " after combat"))