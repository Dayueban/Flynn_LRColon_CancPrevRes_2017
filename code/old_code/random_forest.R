# random forest and AUCRF of left vs right, stool vs mucosa
#Kaitlin Flynn, Schloss lab, updated 3 24 17
#load packages
pack_used <- c('randomForest','ggplot2', 'pROC', 'knitr','dplyr','AUCRF', 'tidyr', 'caret')
for (dep in pack_used){
  if (dep %in% installed.packages()[,"Package"] == FALSE){
    install.packages(as.character(dep), repos = 'http://cran.us.r-project.org', 
                     quiet=TRUE);
  }
  library(dep, verbose=FALSE, character.only=TRUE)
}

#load in all of the files, get rel abund of >1% and/or >10%

meta_file <- read.table(file='data/raw/kws_metadata.tsv', header = T)
shared_file <- read.table(file='data/mothur/kws_final.an.shared', sep = '\t', header=T, row.names=2)
tax_file <- read.table(file='data/mothur/kws_final.an.cons.taxonomy', sep = '\t', header=T, row.names=1)
filter_shared <- shared_file <- read.table(file='data/mothur/kws_final.an.0.03.filter.shared', sep = '\t', header=T, row.names=2)

#make OTU abundance file
#Create df with relative abundances
shared_file <- subset(shared_file, select = -c(numOtus, label))
shared_meta <- merge(meta_file, shared_file, by.x='group', by.y='row.names')

filter_shared <- subset(shared_file, select = -c(numOtus, label))
filter_meta <- merge(meta_file, filter_shared, by.x='group', by.y='row.names')

rel_abund <- 100*shared_file/unique(apply(shared_file, 1, sum))

filter_relabund <- 100*filter_shared/unique(apply(filter_shared, 1, sum))

#Create vector of OTUs with median abundances >1%
OTUs_1 <- apply(rel_abund, 2, max) > 1
OTU_list <- colnames(rel_abund)[OTUs_1]
#get df of just top OTUs
rel_abund_top <- rel_abund[, OTUs_1]
rel_meta <- merge(meta_file, rel_abund_top, by.x='group', by.y="row.names")

OTUs_filter <- apply(filter_relabund, 2, max) >1
OTU_filter_list <- colnames(filter_relabund)[OTUs_filter]

filter_top <- filter_relabund[, OTUs_filter]
filter_abund_meta <- merge(meta_file, filter_top, by.x='group', by.y='row.names')

seed <- 1
n_trees <- 2001

source('code/random_functions.R')
source('code/tax_level.R')

#####RandomForest###########################################################################################
#build randomForest model for each location comparison using randomize_loc function 
rf_left <- randomize_loc(rel_meta, "LB", "LS") #OOB 10.26%
rf_right <- randomize_loc(rel_meta, "RB", "RS") #OOB 53%
rf_bowel <- randomize_loc(rel_meta, "LB", "RB") #OOB 25.64%
rf_lumen <- randomize_loc(rel_meta, "LS", "RS") #OOB 69.23%
rf_exitRlum <- randomize_loc(rel_meta, "RS", "SS")
rf_exitLlum <- randomize_loc(rel_meta, "LS", "SS")

#and for each site
rf_all <- randomize_site(rel_meta, "mucosa", "stool")
rf_exitlum <- randomize_site(rel_meta, "stool", "exit")
rf_exitmuc <- randomize_site(rel_meta, "mucosa", "exit")


#####AUCRF#####################################################################################
#wait should i plot new and old models on the same plot for lab meeting? YES. do in other script window 

# create RF model with AUCRF outputs top OTUs
aucrf_data_left_bs <- auc_loc(rel_meta, "LB", "LS")
aucrf_data_LRbowel <- auc_loc(rel_meta, "LB", "RB")
aucrf_data_right_bs <- auc_loc(rel_meta, "RB", "RS")
aucrf_data_LRlumen <- auc_loc(rel_meta, "LS", "RS")
aucrf_data_allum <- auc_site(rel_meta, "mucosa", "stool")

#testing building the model on filtered data
aucrf_filter_left_bs <- auc_loc(filter_abund_meta, "LB", "LS") # this works but we need it to output an aucrf object. change function?

#testing the AUCRFcv approach for optimalset feature selection 
testsub <- subset(filter_abund_meta, location %in% c("LB", "LS"))
testsub$location <- factor(testsub$location)
levels(testsub$location) <- c(1:length(levels(testsub$location))-1)

rf_aucrf <- AUCRF(location~., data=select(testsub, location, contains("Otu")), ntree=n_trees, pdel=0.05, ranking="MDA")
aucrf_cv_left_bs <- AUCRFcv(rf_aucrf, nCV=10, M=20)
optimal_leftbs <- OptimalSet(aucrf_cv_left_bs)

#testing AUCRFcv approach on unfiltered data
left_test <- subset(rel_meta, location %in% c("LB", "LS"))
left_test$location <- factor(left_test$location)
#change levels of variable of interest to 0/1
levels(left_test$location) <- c(1:length(levels(left_test$location))-1)
# create RF model
set.seed(seed)
rf_left_test <- AUCRF(location ~ ., data = select(left_test, location, contains("Otu")),
                  ntree = n_trees, pdel = 0.05, ranking = 'MDA')

aucrf_cv_left_unfiltered <- AUCRFcv(rf_left_test, nCV=10, M=20)
optimal_left_unfiltered <- OptimalSet(aucrf_cv_left_unfiltered)

#take top ten OTUs from optimal set, put in a list, then use list to subset filtered data

left_top6 <- as.vector(optimal_left_unfiltered$Name)
#but this is the same list as the Xopt from the rf object. so do i even need to do the aucrfcv with optimim set?? this is still main issue to figure out
#maybe need to do 100 iters??
#put new subsetted data in to randomForest, get auc, do CV

#then do that for all models and plot 

#lets try testing with a bigger dataset 
bowel_test <- subset(rel_meta, location %in% c("LB", "RB"))
bowel_test$location <- factor(bowel_test$location)
#change levels of variable of interest to 0/1
levels(bowel_test$location) <- c(1:length(levels(bowel_test$location))-1)
# create RF model
set.seed(seed)
rf_bowel_test <- AUCRF(location ~ ., data = select(bowel_test, location, contains("Otu")),
                      ntree = n_trees, pdel = 0.05, ranking = 'MDA')

aucrf_cv_bowel_unfiltered <- AUCRFcv(rf_bowel_test, nCV=10, M=100)
optimal_bowel_unfiltered <- OptimalSet(aucrf_cv_bowel_unfiltered)

bowel_top10 <- as.vector(optimal_bowel_unfiltered$Name[1:10])

#subset shared to just be these columns then run randomForest again 

bowel_top10_shared <- subset(rel_meta, select=colnames(rel_meta) %in% c('location',bowel_top10))
rf_bowel_top10 <- randomize_loc(bowel_top10_shared, "LB", "RB")
auc_bowel_top10 <- auc_loc(bowel_top10_shared, "LB", "RB")


######doing the feat selection thing for the LS and RS model, see if it changes AUC or model, then decide if all of this is worth it.

lumen_test <- subset(rel_meta, location %in% c("LS", "RS"))
lumen_test$location <- factor(lumen_test$location)
levels(lumen_test$location) <- c(1:length(levels(lumen_test$location))-1)
set.seed(seed)
rf_lumen_test <- AUCRF(location ~ ., data = select(lumen_test, location, contains("Otu")),
                       ntree = n_trees, pdel = 0.05, ranking = 'MDA')

aucrf_cv_lumen_unfiltered <- AUCRFcv(rf_bowel_test, nCV=10, M=100)
optimal_lumen_unfiltered <- OptimalSet(aucrf_cv_lumen_unfiltered)

lumen_top10 <- as.vector(optimal_lumen_unfiltered$Name[1:10])

#subset shared to just be these columns then run randomForest again, then 10fold cv again 

bowel_top10_shared <- subset(rel_meta, select=colnames(rel_meta) %in% c('location',bowel_top10))
rf_bowel_top10 <- randomize_loc(bowel_top10_shared, "LB", "RB")
auc_bowel_top10 <- auc_loc(bowel_top10_shared, "LB", "RB")
cv10f_roc_muc10$auc #Area under the curve: 0.9159

lumen_top10_shared <- subset(rel_meta, select=colnames(rel_meta) %in% c('location',lumen_top10))
rf_lumen_top10 <- randomize_loc(lumen_top10_shared, "LS", "RS")
auc_lumen_top10 <- auc_loc(lumen_top10_shared, "LS", "RS")

cv10f_roc_lum10$auc #Area under the curve: 0.6243



#need to fix specific function for these to output just the rf object 
#rf_exitlum_aucrf <- auc_site(rel_meta, "stool", "exit") # not working 
rf_exitLlum_aucrf <- auc_loc(rel_meta, "LB", "SS")
rf_exitRlum_aucrf <- auc_loc(rel_meta, "RB", "SS")


########Cross-Validation#################################################################
#10 fold cross validation for all lumen vs mucosa 
iters <- 100
cv10f_aucs <- c()
cv10f_all_resp <- c()
cv10f_all_pred <- c()
for(j in 1:iters){
  set.seed(j)
  sampling <- sample(1:nrow(aucrf_data_allum),nrow(aucrf_data_allum),replace=F)
  cv10f_probs <- rep(NA,78)
  for(i in seq(1,77,7)){
    train <- aucrf_data_allum[sampling[-(i:(i+6))],]
    test <- aucrf_data_allum[sampling[i:(i+6)],]
    set.seed(seed)
    temp_model <- AUCRF(site~., data=train, pdel=0.99, ntree=500)
    cv10f_probs[sampling[i:(i+6)]] <- predict(temp_model$RFopt, test, type='prob')[,2]
  }
  cv10f_roc <- roc(aucrf_data_allum$site~cv10f_probs)
  cv10f_all_pred <- c(cv10f_all_pred, cv10f_probs)
  cv10f_all_resp <- c(cv10f_all_resp, aucrf_data_allum$site)
  cv10f_aucs[j] <- cv10f_roc$auc #stores aucs for all iterations, can use to calc IQR
}
cv10f_roc <- roc(cv10f_all_resp~cv10f_all_pred)

#10fold CV for L lumen vs L mucosa
iters <- 100
cv10f_aucs <- c()
cv10f_all_resp_left_bs <- c()
cv10f_all_pred_left_bs <- c()
for(j in 1:iters){
  set.seed(j)
  sampling <- sample(1:nrow(aucrf_data_left_bs),nrow(aucrf_data_left_bs),replace=F)
  cv10f_probs <- rep(NA,39)
  for(i in seq(1,36,4)){
    train_left_bs <- aucrf_data_left_bs[sampling[-(i:(i+3))],]
    test_left_bs <- aucrf_data_left_bs[sampling[i:(i+3)],]
    set.seed(seed)
    temp_model_left_bs <- AUCRF(location~., data=train_left_bs, pdel=0.99, ntree=500)
    cv10f_probs[sampling[i:(i+3)]] <- predict(temp_model_left_bs$RFopt, test_left_bs, type='prob')[,2]
  }
  cv10f_roc_left_bs <- roc(aucrf_data_left_bs$location~cv10f_probs)
  cv10f_all_pred_left_bs <- c(cv10f_all_pred_left_bs, cv10f_probs)
  cv10f_all_resp_left_bs <- c(cv10f_all_resp_left_bs, aucrf_data_left_bs$location)
  cv10f_aucs[j] <- cv10f_roc_left_bs$auc #stores aucs for all iterations, can use to calc IQR
}
cv10f_roc_left_bs <- roc(cv10f_all_resp_left_bs~cv10f_all_pred_left_bs)

#10fold CV for R lumen vs R mucosa
iters <- 100
cv10f_aucs <- c()
cv10f_all_resp_right_bs <- c()
cv10f_all_pred_right_bs <- c()
for(j in 1:iters){
  set.seed(j)
  sampling <- sample(1:nrow(aucrf_data_right_bs),nrow(aucrf_data_right_bs),replace=F)
  cv10f_probs <- rep(NA,39)
  for(i in seq(1,36,4)){
    train_right_bs <- aucrf_data_right_bs[sampling[-(i:(i+3))],]
    test_right_bs <- aucrf_data_right_bs[sampling[i:(i+3)],]
    set.seed(seed)
    temp_model_right_bs <- AUCRF(location~., data=train_right_bs, pdel=0.99, ntree=500)
    cv10f_probs[sampling[i:(i+3)]] <- predict(temp_model_right_bs$RFopt, test_right_bs, type='prob')[,2]
  }
  cv10f_roc_right_bs <- roc(aucrf_data_right_bs$location~cv10f_probs)
  cv10f_all_pred_right_bs <- c(cv10f_all_pred_right_bs, cv10f_probs)
  cv10f_all_resp_right_bs <- c(cv10f_all_resp_right_bs, aucrf_data_right_bs$location)
  cv10f_aucs[j] <- cv10f_roc_right_bs$auc #stores aucs for all iterations, can use to calc IQR
}
cv10f_roc_right_bs <- roc(cv10f_all_resp_right_bs~cv10f_all_pred_right_bs)

#10 fold cross validation for L vs R mucosa

iters <- 100
cv10f_aucs_muc <- c()
cv10f_all_resp_muc <- c()
cv10f_all_pred_muc <- c()
for(j in 1:iters){
  set.seed(j)
  sampling_muc <- sample(1:nrow(aucrf_data_LRbowel),nrow(aucrf_data_LRbowel),replace=F)
  cv10f_probs_muc <- rep(NA,39)
  for(i in seq(1,36,4)){
    train_muc <- aucrf_data_LRbowel[sampling_muc[-(i:(i+3))],]
    test_muc <- aucrf_data_LRbowel[sampling_muc[i:(i+3)],]
    set.seed(seed)
    temp_model_muc <- AUCRF(location~., data=train_muc, pdel=0.99, ntree=500)
    cv10f_probs_muc[sampling_muc[i:(i+3)]] <- predict(temp_model_muc$RFopt, test_muc, type='prob')[,2]
  }
  cv10f_roc_muc <- roc(aucrf_data_LRbowel$location~cv10f_probs_muc)
  cv10f_all_pred_muc <- c(cv10f_all_pred_muc, cv10f_probs_muc)
  cv10f_all_resp_muc <- c(cv10f_all_resp_muc, aucrf_data_LRbowel$location)
  cv10f_aucs_muc[j] <- cv10f_roc_muc$auc #stores aucs for all iterations, can use to calc IQR
}
cv10f_roc_muc <- roc(cv10f_all_resp_muc~cv10f_all_pred_muc)

######10fold cross v with reduced feature input
#10 fold cross validation for L vs R mucosa

iters <- 100
cv10f_aucs_muc10 <- c()
cv10f_all_resp_muc10 <- c()
cv10f_all_pred_muc10 <- c()
for(j in 1:iters){
  set.seed(j)
  sampling_muc <- sample(1:nrow(auc_bowel_top10),nrow(auc_bowel_top10),replace=F)
  cv10f_probs_muc10 <- rep(NA,39)
  for(i in seq(1,36,4)){
    train_muc <- auc_bowel_top10[sampling_muc[-(i:(i+3))],]
    test_muc <- auc_bowel_top10[sampling_muc[i:(i+3)],]
    set.seed(seed)
    temp_model_muc <- AUCRF(location~., data=train_muc, pdel=0.99, ntree=500)
    cv10f_probs_muc10[sampling_muc[i:(i+3)]] <- predict(temp_model_muc$RFopt, test_muc, type='prob')[,2]
  }
  cv10f_roc_muc10 <- roc(auc_bowel_top10$location~cv10f_probs_muc10)
  cv10f_all_pred_muc10 <- c(cv10f_all_pred_muc10, cv10f_probs_muc10)
  cv10f_all_resp_muc10 <- c(cv10f_all_resp_muc10, auc_bowel_top10$location)
  cv10f_aucs_muc10[j] <- cv10f_roc_muc10$auc #stores aucs for all iterations, can use to calc IQR
}
cv10f_roc_muc10 <- roc(cv10f_all_resp_muc10~cv10f_all_pred_muc10)


#10 fold cross validation for L vs R lumen
iters <- 100
cv10f_aucs_lum <- c()
cv10f_all_resp_lum <- c()
cv10f_all_pred_lum <- c()
for(j in 1:iters){
  set.seed(j)
  sampling_lum <- sample(1:nrow(aucrf_data_LRlumen),nrow(aucrf_data_LRlumen),replace=F)
  cv10f_probs_lum <- rep(NA,39)
  for(i in seq(1,36,4)){
    train_lum <- aucrf_data_LRlumen[sampling_lum[-(i:(i+3))],]
    test_lum <- aucrf_data_LRlumen[sampling_lum[i:(i+3)],]
    set.seed(seed)
    temp_model_lum <- AUCRF(location~., data=train_lum, pdel=0.99, ntree=500)
    cv10f_probs_lum[sampling_lum[i:(i+3)]] <- predict(temp_model_lum$RFopt, test_lum, type='prob')[,2]
  }
  cv10f_roc_lum <- roc(aucrf_data_LRlumen$location~cv10f_probs_lum)
  cv10f_all_pred_lum <- c(cv10f_all_pred_lum, cv10f_probs_lum)
  cv10f_all_resp_lum <- c(cv10f_all_resp_lum, aucrf_data_LRlumen$location)
  cv10f_aucs_lum[j] <- cv10f_roc_lum$auc #stores aucs for all iterations, can use to calc IQR
}
cv10f_roc_lum <- roc(cv10f_all_resp_lum~cv10f_all_pred_lum)

#####with limited input
#10 fold cross validation for L vs R lumen
iters <- 100
cv10f_aucs_lum10 <- c()
cv10f_all_resp_lum10 <- c()
cv10f_all_pred_lum10 <- c()
for(j in 1:iters){
  set.seed(j)
  sampling_lum <- sample(1:nrow(auc_lumen_top10),nrow(auc_lumen_top10),replace=F)
  cv10f_probs_lum10 <- rep(NA,39)
  for(i in seq(1,36,4)){
    train_lum <- auc_lumen_top10[sampling_lum[-(i:(i+3))],]
    test_lum <- auc_lumen_top10[sampling_lum[i:(i+3)],]
    set.seed(seed)
    temp_model_lum <- AUCRF(location~., data=train_lum, pdel=0.99, ntree=500)
    cv10f_probs_lum10[sampling_lum[i:(i+3)]] <- predict(temp_model_lum$RFopt, test_lum, type='prob')[,2]
  }
  cv10f_roc_lum10 <- roc(auc_lumen_top10$location~cv10f_probs_lum10)
  cv10f_all_pred_lum10 <- c(cv10f_all_pred_lum10, cv10f_probs_lum10)
  cv10f_all_resp_lum10 <- c(cv10f_all_resp_lum10, auc_lumen_top10$location)
  cv10f_aucs_lum10[j] <- cv10f_roc_lum10$auc #stores aucs for all iterations, can use to calc IQR
}
cv10f_roc_lum10 <- roc(cv10f_all_resp_lum10~cv10f_all_pred_lum10)






########Plots!#######################################################################################################
#Lumen vs mucosa plot 
par(mar=c(4,4,1,1))
plot(c(1,0),c(0,1), type='l', lty=3, xlim=c(1.01,0), ylim=c(-0.01,1.01), xaxs='i', yaxs='i', ylab='', xlab='', cex.axis=1.5)
plot(cv10f_roc_right_bs, col='blue', lwd=3, add=T, lty=1)
#plot(cv10f_roc, col = 'purple', lwd=3, add=T, lty=1)
plot(cv10f_roc_left_bs, col = 'red', lwd=3, add=T, lty=1)
mtext(side=2, text="Sensitivity", line=2.5, cex=1.5)
mtext(side=1, text="Specificity", line=2.5, cex=1.5)
legend('bottom', legend=c(#sprintf('Lumen vs Mucosa, 10-fold CV, AUC = 0.925'),
  sprintf('D Lumen vs D Mucosa, 10-fold CV, AUC =0.980'),
  sprintf('P Lumen vs P Mucosa, 10-fold CV, AUC = 0.797')
  #sprintf('OOB vs Leave-1-out: p=%.2g', roc.test(otu_euth_roc,LOO_roc)$p.value),
  #sprintf('OOB vs 10-fold CV: p=%.2g', roc.test(otu_euth_roc,cv10f_roc)$p.value)
),lty=c(1, 1, 1), lwd=3, col=c('red', 'blue'), bty='n', cex=1.2)


#left vs right mucosa and lumen plot 
par(mar=c(4,4,1,1))
plot(c(1,0),c(0,1), type='l', lty=3, xlim=c(1.01,0), ylim=c(-0.01,1.01), xaxs='i', yaxs='i', ylab='', xlab='', cex.axis=1.5)
plot(cv10f_roc_muc,col = 'green4', lwd=3, add=T, lty=1) #r vs l mucosa cross validation
plot(cv10f_roc_lum, col = 'orange', lwd=3, add=T, lty=1) #r vs l lumen cross validation
mtext(side=2, text="Sensitivity", line=2.5, cex=1.2)
mtext(side=1, text="Specificity", line=2.5, cex=1.2)
legend('bottom', legend=c(sprintf('D mucosa vs P mucosa 10-fold CV, AUC = 0.9159'),
                          sprintf('D lumen vs P lumen 10-fold CV, AUC = 0.7551')
                          # sprintf('OOB vs Leave-1-out: p=%.2g', roc.test(otu_euth_roc,LOO_roc)$p.value),
                          # sprintf('OOB vs 10-fold CV: p=%.2g', roc.test(otu_euth_roc,cv10f_roc)$p.value)
),lty=c(1, 1), lwd=2, col=c('green4', 'orange'), bty='n', cex=1.2)


#####10fold plot left vs right mucosa and lumen plot 
par(mar=c(4,4,1,1))
plot(c(1,0),c(0,1), type='l', lty=3, xlim=c(1.01,0), ylim=c(-0.01,1.01), xaxs='i', yaxs='i', ylab='', xlab='', cex.axis=1.5)
plot(cv10f_roc_muc10,col = 'green4', lwd=3, add=T, lty=1) #r vs l mucosa cross validation
plot(cv10f_roc_lum10, col = 'orange', lwd=3, add=T, lty=1) #r vs l lumen cross validation
mtext(side=2, text="Sensitivity", line=2.5, cex=1.2)
mtext(side=1, text="Specificity", line=2.5, cex=1.2)
legend('bottom', legend=c(sprintf('D mucosa vs P mucosa 10-fold CV, AUC = 0.912'),
                          sprintf('D lumen vs P lumen 10-fold CV, AUC = 0.6243')
                          # sprintf('OOB vs Leave-1-out: p=%.2g', roc.test(otu_euth_roc,LOO_roc)$p.value),
                          # sprintf('OOB vs 10-fold CV: p=%.2g', roc.test(otu_euth_roc,cv10f_roc)$p.value)
),lty=c(1, 1), lwd=2, col=c('green4', 'orange'), bty='n', cex=1.2)


#generate entire figure just of exit comparisons 
par(mar=c(4,4,1,1))
plot(c(1,0),c(0,1), type='l', lty=3, xlim=c(1.01,0), ylim=c(-0.01,1.01), xaxs='i', yaxs='i', ylab='', xlab='')
plot(otu_exitlum_roc, col='red', lwd=2, add=T, lty=1) #all lumen vs exit 
plot(otu_exitmuc_roc, col='blue', lwd=2, add=T, lty=1) #all mucosa vs exit
plot(otu_exitLlum_roc, col='green4', lwd=2, add=T, lty=1) #left lumen vs exit 
plot(otu_exitRlum_roc, col='purple', lwd=2, add=T, lty=1) #right lumen vs left lumen 
#plot(otu_all_roc, col = 'pink', lwd=2, add =T, lty=1)
mtext(side=2, text="Sensitivity", line=2.5)
mtext(side=1, text="Specificity", line=2.5)
legend('bottom', legend=c(sprintf('All lumen vs exit, AUC = 0.882'),
                          sprintf('All mucosa vs exit, AUC = 0.991'),
                          sprintf('L lumen vs exit, AUC = 0.802'),
                          sprintf('R lumen vs exit, AUC = 0.934')
                          # sprintf('all lumen vs all mucosa, AUC = 0.922')#,
                          #                               sprintf('OOB vs Leave-1-out: p=%.2g', roc.test(otu_euth_roc,LOO_roc)$p.value),
                          #                               sprintf('OOB vs 10-fold CV: p=%.2g', roc.test(otu_euth_roc,cv10f_roc)$p.value)
), lty=1, lwd=2, col=c('red','blue', 'green4', 'purple'), bty='n')


###########Importance plots for OTUs!##############################################################################################################################
tax_function <- 'code/tax_level.R'
source(tax_function)

n_features <- 10
#importance for left bowel vs lumen 
importance_sorted_rfleft <- sort(importance(rf_left)[,1], decreasing = T)
top_important_OTU_rfleft <- data.frame(head(importance_sorted_rfleft, n_features))
colnames(top_important_OTU_rfleft) <- 'Importance'
top_important_OTU_rfleft$OTU <- rownames(top_important_OTU_rfleft)
otu_taxa_rfleft <- get_tax(1, top_important_OTU_rfleft$OTU, tax_file)
ggplot(data = top_important_OTU_rfleft, aes(x = factor(OTU), y = Importance)) + 
  geom_point() + scale_x_discrete(limits = rev(top_important_OTU_rfleft$OTU),
                                  labels = rev(paste(otu_taxa_rfleft[,1],' (',
                                                     rownames(otu_taxa_rfleft),')',
                                                     sep=''))) +
  labs(x= '', y = '% Increase in MSE') + theme_bw() + coord_flip() + ggtitle('LB vs LS')

#RB vs RS
importance_sorted_rfright <- sort(importance(rf_right)[,1], decreasing = T)
top_important_OTU_rfright <- data.frame(head(importance_sorted_rfright, n_features))
colnames(top_important_OTU_rfright) <- 'Importance'
top_important_OTU_rfright$OTU <- rownames(top_important_OTU_rfright)
otu_taxa_rfright <- get_tax(1, top_important_OTU_rfright$OTU, tax_file)
ggplot(data = top_important_OTU_rfright, aes(x = factor(OTU), y = Importance)) + 
    geom_point() + scale_x_discrete(limits = rev(top_important_OTU_rfright$OTU),
                                    labels = rev(paste(otu_taxa_rfright[,1],' (',
                                                       rownames(otu_taxa_rfright),')',
                                                       sep=''))) +
    labs(x= '', y = '% Increase in MSE') + theme_bw() + coord_flip() + ggtitle('RB vs RS')
  
#all lumen vs mucosa importance
importance_sorted_rfall <- sort(importance(rf_all)[,1], decreasing = T)
top_important_OTU_rfall <- data.frame(head(importance_sorted_rfall, n_features))
colnames(top_important_OTU_rfall) <- 'Importance'
top_important_OTU_rfall$OTU <- rownames(top_important_OTU_rfall)
otu_taxa_rfall <- get_tax(1, top_important_OTU_rfall$OTU, tax_file)
ggplot(data = top_important_OTU_rfall, aes(x = factor(OTU), y = Importance)) + 
  geom_point() + scale_x_discrete(limits = rev(top_important_OTU_rfall$OTU),
                                  labels = rev(paste(otu_taxa_rfall[,1],' (',
                                                     rownames(otu_taxa_rfall),')',
                                                     sep=''))) +
  labs(x= '', y = '% Increase in MSE') + theme_bw() + coord_flip() + ggtitle('All mucosa vs lumen')


#L mucosa vs R mucosa importance
importance_sorted_rfbowel <- sort(importance(rf_bowel)[,1], decreasing = T)
top_important_OTU_rfbowel <- data.frame(head(importance_sorted_rfbowel, n_features))
colnames(top_important_OTU_rfbowel) <- 'Importance'
top_important_OTU_rfbowel$OTU <- rownames(top_important_OTU_rfbowel)
otu_taxa_rfbowel <- get_tax(1, top_important_OTU_rfbowel$OTU, tax_file)
ggplot(data = top_important_OTU_rfbowel, aes(x = factor(OTU), y = Importance)) + 
  geom_point() + scale_x_discrete(limits = rev(top_important_OTU_rfbowel$OTU),
                                  labels = rev(paste(otu_taxa_rfbowel[,1],' (',
                                                     rownames(otu_taxa_rfbowel),')',
                                                     sep=''))) +
  labs(x= '', y = '% Increase in MSE') + theme_bw() + coord_flip() + ggtitle('L mucosa vs R mucosa')


#L lumen vs R lumen 
importance_sorted_rflumen <- sort(importance(rf_lumen)[,1], decreasing = T)
top_important_OTU_rflumen <- data.frame(head(importance_sorted_rflumen, n_features))
colnames(top_important_OTU_rflumen) <- 'Importance'
top_important_OTU_rflumen$OTU <- rownames(top_important_OTU_rflumen)
otu_taxa_rflumen <- get_tax(1, top_important_OTU_rflumen$OTU, tax_file)

ggplot(data = top_important_OTU_rflumen, aes(x = factor(OTU), y = Importance)) + 
  geom_point() + scale_x_discrete(limits = rev(top_important_OTU_rflumen$OTU),
                                  labels = rev(paste(otu_taxa_rflumen[,1],' (',
                                                     rownames(otu_taxa_rflumen),')',
                                                     sep=''))) +
  labs(x= '', y = '% Increase in MSE') + theme_bw() + coord_flip() + ggtitle('L lumen vs R lumen')

##############################################################################################################################
#####Relative abundance plots#####
#get top 5 OTUs and plot relative abundance
all_otu_feat <- colnames(aucrf_data_allum[2:6])
otu_taxa_all <- get_tax(1, all_otu_feat, tax_file)

#Abundance stripchart for most predictive otus 
lumen_abunds <- shared_meta[shared_meta$site=='stool', all_otu_feat]/10000 + 1e-4
mucosa_abunds <- shared_meta[shared_meta$site=='mucosa', all_otu_feat]/10000 + 1e-4

par(mar=c(4, 9, 1, 1))
plot(1, type="n", ylim=c(0,length(all_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n")
index <- 1
for(i in all_otu_feat){
  stripchart(at=index-0.35, jitter(lumen_abunds[,i], amount=1e-5), pch=21, bg="royalblue1", method="jitter", jitter=0.2, add=T, cex=1, lwd=0.5)
  stripchart(at=index+0.35, jitter(mucosa_abunds[,i], amount=1e-5), pch=21, bg="orange", method="jitter", jitter=0.2, add=T, cex=1, lwd=0.5)
  segments(mean(lumen_abunds[,i]),index-0.7,mean(lumen_abunds[,i]),index, lwd=3)
  segments(mean(mucosa_abunds[,i]),index+0.7,mean(mucosa_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=otu_taxa_all$tax_label, las=1, line=-0.5, tick=F, cex.axis=0.8)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"))
legend('topright', legend=c("mucosa", "lumen"), pch=c(21, 21), pt.bg=c("orange","royalblue1"), cex=0.7)


#just LB vs LS 
left_otu_feat <- colnames(aucrf_data_left_bs[2:6])
otu_taxa_left <- get_tax(1, left_otu_feat, tax_file)
#Abundance stripchart or most predictive otus
ls_abunds <- shared_meta[shared_meta$location=='LS', left_otu_feat]/10000 + 1e-4
lb_abunds <- shared_meta[shared_meta$location=='LB', left_otu_feat]/10000 + 1e-4

par(mar=c(5, 15, 1, 1))
plot(1, type="n", ylim=c(0,length(left_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n", cex.lab=1.5)
index <- 1
for(i in left_otu_feat){
  stripchart(at=index-0.35, jitter(ls_abunds[,i], amount=1e-5), pch=21, bg="lightblue", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  stripchart(at=index+0.35, jitter(lb_abunds[,i], amount=1e-5), pch=21, bg="yellow", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  segments(median(ls_abunds[,i]),index-0.7,median(ls_abunds[,i]),index, lwd=2)
  segments(median(lb_abunds[,i]),index+0.7,median(lb_abunds[,i]),index, lwd=2)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=otu_taxa_left$tax_label, las=1, line=-0.5, tick=F, cex.axis=1.2)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"), cex.axis=1.2)
legend('topright', legend=c("Left mucosa", "Left lumen"), pch=c(21, 21), pt.bg=c("yellow","lightblue"), cex=1.2)

#RB vs RS

right_otu_feat <- colnames(aucrf_data_right_bs[2:6])
otu_taxa_right <- get_tax(1, right_otu_feat, tax_file)
#Abundance stripchart or most predictive otus
rs_test <- shared_meta[shared_meta$location=='RS', right_otu_feat]/10000 + 1e-4

rs_abunds <- shared_meta[shared_meta$location=='RS', right_otu_feat]/10000 + 1e-4
rb_abunds <- shared_meta[shared_meta$location=='RB', right_otu_feat]/10000 + 1e-4

par(mar=c(5, 15, 1, 1))
plot(1, type="n", ylim=c(0,length(right_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n", cex.lab=1.5)
index <- 1
for(i in right_otu_feat){
  stripchart(at=index-0.35, jitter(rs_abunds[,i], amount=1e-5), pch=21, bg="purple", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  stripchart(at=index+0.35, jitter(rb_abunds[,i], amount=1e-5), pch=21, bg="orange", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  segments(median(rs_abunds[,i]),index-0.7,median(rs_abunds[,i]),index, lwd=3)
  segments(median(rb_abunds[,i]),index+0.7,median(rb_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=otu_taxa_right$tax_label, las=1, line=-0.5, tick=F, cex.axis=1.2)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"), cex.axis=1.2)
legend('topright', legend=c("Right mucosa", "Right lumen"), pch=c(21, 21), pt.bg=c("orange","purple"), cex=1.2)


#Lb vs Rb
LRbowel_otu_feat <- colnames(aucrf_data_LRbowel[2:6])
otu_taxa_LRbowel <- get_tax(1, LRbowel_otu_feat, tax_file)
#Abundance stripchart or most predictive otus 
lb_abunds <- shared_meta[shared_meta$location=='LB', LRbowel_otu_feat]/10000 + 1e-4
rblb_abunds <- shared_meta[shared_meta$location=='RB', LRbowel_otu_feat]/10000 + 1e-4

par(mar=c(5, 15, 1, 1))
plot(1, type="n", ylim=c(0,length(LRbowel_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n", cex.lab=1.5)
index <- 1
for(i in LRbowel_otu_feat){
  stripchart(at=index-0.35, jitter(lb_abunds[,i], amount=1e-5), pch=21, bg="darkgreen", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  stripchart(at=index+0.35, jitter(rblb_abunds[,i], amount=1e-5), pch=21, bg="pink", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  segments(median(lb_abunds[,i]),index-0.7,median(lb_abunds[,i]),index, lwd=3)
  segments(median(rblb_abunds[,i]),index+0.7,median(rblb_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=otu_taxa_LRbowel$tax_label, las=1, line=-0.5, tick=F, cex.axis=1.2)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"), cex.axis=1.2)
legend('topright', legend=c("Left mucosa", "Right mucosa"), pch=c(21, 21), pt.bg=c("darkgreen","pink"), cex=1.2)


#LS vs RS
LRlumen_otu_feat <- colnames(aucrf_data_LRlumen[2:6])
otu_taxa_LRlumen <- get_tax(1, LRlumen_otu_feat, tax_file)
#Abundance stripchart or most predictive otus 
lsrs_abunds <- shared_meta[shared_meta$location=='LS', LRlumen_otu_feat]/10000 + 1e-4
rsls_abunds <- shared_meta[shared_meta$location=='RS', LRlumen_otu_feat]/10000 + 1e-4

par(mar=c(5, 15, 1, 1))
plot(1, type="n", ylim=c(0,length(LRlumen_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n", cex.lab=1.5)
index <- 1
for(i in LRlumen_otu_feat){
  stripchart(at=index-0.35, jitter(lsrs_abunds[,i], amount=1e-5), pch=21, bg="brown", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  stripchart(at=index+0.35, jitter(rsls_abunds[,i], amount=1e-5), pch=21, bg="magenta", method="jitter", jitter=0.2, add=T, cex=1.2, lwd=0.5)
  segments(median(lsrs_abunds[,i]),index-0.7,median(lsrs_abunds[,i]),index, lwd=3)
  segments(median(rsls_abunds[,i]),index+0.7,median(rsls_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=otu_taxa_LRlumen$tax_label, las=1, line=-0.5, tick=F, cex.axis=1.2)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"), cex.axis=1.2)
legend('topright', legend=c("Left lumen", "Right lumen"), pch=c(21, 21), pt.bg=c("brown","magenta"), cex=1.2)



######################################################## build and export figure 
#export as PDF

plot_file <- '~/Documents/Flynn_LRColon_XXXX_2017/submission/figure_5.pdf'
pdf(file=plot_file, width=6, height=7)
layout(matrix(c(1,
                2), 
              nrow=2, byrow = TRUE))

#RB vs RS

right_otu_feat <- colnames(aucrf_data_right_bs[2:6])
otu_taxa_right <- get_tax(1, right_otu_feat, tax_file)
otu_taxa_right <- separate(otu_taxa_right, tax_label, into = c("OTU", "otu_num"), sep = "\\(")
formatted4 <- lapply(1:nrow(otu_taxa_right), function(i) bquote(paste(italic(.(otu_taxa_right$OTU[i])), "(", .(otu_taxa_right$otu_num[i]), sep=" ")))
#Abundance stripchart or most predictive otus
rs_abunds <- shared_meta[shared_meta$location=='RS', right_otu_feat]/10000 + 1e-4
rb_abunds <- shared_meta[shared_meta$location=='RB', right_otu_feat]/10000 + 1e-4

par(mar=c(5, 11, 1, 1))
plot(1, type="n", ylim=c(0,length(right_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n")
index <- 1
for(i in right_otu_feat){
  stripchart(at=index-0.35, jitter(rs_abunds[,i], amount=1e-5), pch=21, bg="white", method="jitter", jitter=0.2, add=T, lwd=0.5)
  stripchart(at=index+0.35, jitter(rb_abunds[,i], amount=1e-5), pch=21, bg="gray29", method="jitter", jitter=0.2, add=T, lwd=0.5)
  segments(median(rs_abunds[,i]),index-0.8,median(rs_abunds[,i]),index, lwd=3)
  segments(median(rb_abunds[,i]),index+0.8,median(rb_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=do.call(expression,formatted4), las=1, line=-0.5, tick=F, cex.axis=0.9)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"))
legend('topright', legend=c("P Muc", "P Lum"), pch=c(21, 21), pt.bg=c("gray29","white"), cex=0.7)

mtext('A', side=2, line=7.5, las=1, adj=2, padj=-4.5, cex=2, font=2)

#just LB vs LS 
left_otu_feat <- colnames(aucrf_data_left_bs[2:6])
otu_taxa_left <- get_tax(1, left_otu_feat, tax_file)
otu_taxa_left <- separate(otu_taxa_left, tax_label, into = c("OTU", "otu_num"), sep = "\\(")
formatted3 <- lapply(1:nrow(otu_taxa_left), function(i) bquote(paste(italic(.(otu_taxa_left$OTU[i])), "(", .(otu_taxa_left$otu_num[i]), sep=" ")))
#Abundance stripchart or most predictive otus
ls_abunds <- shared_meta[shared_meta$location=='LS', left_otu_feat]/10000 + 1e-4
lb_abunds <- shared_meta[shared_meta$location=='LB', left_otu_feat]/10000 + 1e-4

par(mar=c(5, 11, 1, 1))
plot(1, type="n", ylim=c(0,length(left_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n")
index <- 1
for(i in left_otu_feat){
  stripchart(at=index-0.35, jitter(ls_abunds[,i], amount=1e-5), pch=21, bg="white", method="jitter", jitter=0.2, add=T, lwd=0.5)
  stripchart(at=index+0.35, jitter(lb_abunds[,i], amount=1e-5), pch=21, bg="gray29", method="jitter", jitter=0.2, add=T, lwd=0.5)
  segments(median(ls_abunds[,i]),index-0.8,median(ls_abunds[,i]),index, lwd=3)
  segments(median(lb_abunds[,i]),index+0.8,median(lb_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=do.call(expression, formatted3), las=1, line=-0.5, tick=F, cex.axis=0.9)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"))
legend('topright', legend=c("D Muc", "D Lum"), pch=c(21, 21), pt.bg=c("gray29","white"), cex=0.7)

mtext('B', side=2, line=7.5, las=1, adj=2, padj=-4.5, cex=2, font=2)

dev.off()

####################################### Figure 6 - updated 
#export as PDF

plot_file <- '~/Documents/Flynn_LRColon_XXXX_2017/submission/figure_6.pdf'
pdf(file=plot_file, width=6, height=7)
layout(matrix(c(1,
                2), 
              nrow=2, byrow = TRUE))

#Lb vs Rb
LRbowel_otu_feat <- colnames(aucrf_data_LRbowel[2:6])
otu_taxa_LRbowel <- get_tax(1, LRbowel_otu_feat, tax_file)
otu_taxa_LRbowel <- separate(otu_taxa_LRbowel, tax_label, into = c("OTU", "otu_num"), sep = "\\(")
formatted1 <- lapply(1:nrow(otu_taxa_LRbowel), function(i) bquote(paste(italic(.(otu_taxa_LRbowel$OTU[i])), "(", .(otu_taxa_LRbowel$otu_num[i]), sep=" ")))
#Abundance stripchart or most predictive otus 
lb_abunds <- shared_meta[shared_meta$location=='LB', LRbowel_otu_feat]/10000 + 1e-4
rblb_abunds <- shared_meta[shared_meta$location=='RB', LRbowel_otu_feat]/10000 + 1e-4

par(mar=c(5, 11, 1, 1))
plot(1, type="n", ylim=c(0,length(LRbowel_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n")
index <- 1
for(i in LRbowel_otu_feat){
  stripchart(at=index-0.35, jitter(lb_abunds[,i], amount=1e-5), pch=21, bg="gray29", method="jitter", jitter=0.2, add=T, lwd=0.5)
  stripchart(at=index+0.35, jitter(rblb_abunds[,i], amount=1e-5), pch=21, bg="white", method="jitter", jitter=0.2, add=T, lwd=0.5)
  segments(median(lb_abunds[,i]),index-0.8,median(lb_abunds[,i]),index, lwd=3)
  segments(median(rblb_abunds[,i]),index+0.8,median(rblb_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=do.call(expression,formatted1), las=1, line=-0.5, tick=F, cex.axis=0.9)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"))
legend('topright', legend=c("D Muc", "P Muc"), pch=c(21, 21), pt.bg=c("gray29","white"), cex=0.7)

mtext('A', side=2, line=7.5, las=1, adj=2, padj=-4.5, cex=2, font=2)


#LS vs RS
LRlumen_otu_feat <- colnames(aucrf_data_LRlumen[2:6])
otu_taxa_LRlumen <- get_tax(1, LRlumen_otu_feat, tax_file)
otu_taxa_LRlumen <- separate(otu_taxa_LRlumen, tax_label, into = c("OTU", "otu_num"), sep = "\\(")
formatted <- lapply(1:nrow(otu_taxa_LRlumen), function(i) bquote(paste(italic(.(otu_taxa_LRlumen$OTU[i])), "(", .(otu_taxa_LRlumen$otu_num[i]), sep=" ")))
#Abundance stripchart or most predictive otus 
lsrs_abunds <- shared_meta[shared_meta$location=='LS', LRlumen_otu_feat]/10000 + 1e-4
rsls_abunds <- shared_meta[shared_meta$location=='RS', LRlumen_otu_feat]/10000 + 1e-4

par(mar=c(5, 11, 1, 1))
plot(1, type="n", ylim=c(0,length(LRlumen_otu_feat)*2), xlim=c(1e-4,3), log="x", ylab="", xlab="Relative Abundance (%)", xaxt="n", yaxt="n")
index <- 1
for(i in LRlumen_otu_feat){
  stripchart(at=index-0.35, jitter(lsrs_abunds[,i], amount=1e-5), pch=21, bg="gray29", method="jitter", jitter=0.2, add=T, lwd=0.5)
  stripchart(at=index+0.35, jitter(rsls_abunds[,i], amount=1e-5), pch=21, bg="white", method="jitter", jitter=0.2, add=T, lwd=0.5)
  segments(median(lsrs_abunds[,i]),index-0.8,median(lsrs_abunds[,i]),index, lwd=3)
  segments(median(rsls_abunds[,i]),index+0.8,median(rsls_abunds[,i]),index, lwd=3)
  index <- index + 2
}
axis(2, at=seq(1,index-2,2), labels=do.call(expression, formatted), las=1, line=-0.5, tick=F, cex.axis=0.9)
axis(1, at=c(1e-4, 1e-3, 1e-2, 1e-1, 1), label=c("0", "0.1", "1", "10", "100"))
legend('topright', legend=c("D Lum", "P Lum"), pch=c(21, 21), pt.bg=c("gray29","white"), cex=0.7)

mtext('B', side=2, line=7.5, las=1, adj=2, padj=-4.5, cex=2, font=2)

dev.off()
