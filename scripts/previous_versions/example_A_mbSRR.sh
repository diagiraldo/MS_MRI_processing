#!/usr/bin/zsh

# Example Process session with LR FLAIR (A)
# Diana Giraldo, Nov 2022
# Last update: August 2023

# ANTs directory
ANTS_DIR=/opt/ANTs/bin
# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing/scripts

# STORM directory for model-based SRR in python
STORM_DIR=/home/vlab/STORM
# Code and dependencies for model-based SRR in MATLAB
mSRR_DIR=/home/vlab/SR_MS_eval/ModelBasedSRR
BB_DIR=/home/vlab/SR_MS_eval/BuildingBlocks

# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Raw MRI dir
MRI_DIR=/home/vlab/MS_proj/MS_MRI
# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI

CASE=0030403
DATE=20120507

###################################################################################
# Pre-process images: denoise, brain extraction, N4
for RAW_IM in $(ls ${MRI_DIR}/sub-${CASE}/ses-${DATE}/anat/*(sT1|[Ff][Ll][Aa][Ii][Rr])*.nii*);
do
    zsh ${SCR_DIR}/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
done

###################################################################################
# Use available LR FLAIR to obtain a HR image
slcth=2

# Copy LR FLAIR (and masks) to subfolders
FL_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_preproc
BM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_masks
mkdir -p ${FL_DIR} ${BM_DIR}
for IM in $(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*[Ff][Ll][Aa][Ii][Rr]*preproc.nii.gz); 
do
    SLC=$( mrinfo ${IM} -spacing -config RealignTransform 0 | cut -d" " -f3 )
    if [[ ${SLC} > ${slcth} ]]; then
        cp ${IM} ${FL_DIR}/.
        cp ${IM%_preproc.nii.gz}_brainmask.nii.gz ${BM_DIR}/.
    fi
done

# Histogram matching
HM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_hmatch
zsh ${SCR_DIR}/histmatch_folder.sh ${FL_DIR} ${BM_DIR} ${HM_DIR}
rm -r ${FL_DIR}

# Grid template
ISOVOX=1
HR_grid=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HRgrid_${ISOVOX}mm.nii.gz
zsh ${SCR_DIR}/get_HRgrid.sh ${BM_DIR} ${ISOVOX} ${HR_grid}

# Interpolation
N_IT=4
OP_INTERP=cubic
HRFL_INT=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_interp.nii.gz
zsh ${SCR_DIR}/mSR_interpolation.sh ${HM_DIR} ${BM_DIR} ${HR_grid} ${OP_INTERP} ${N_IT} ${HRFL_INT}

# Model-based SRR with python code
# Adjust LR images
LRADJ_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_adjusted
BMADJ_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_MASK_adjusted
FOVADJ_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FOV_adjusted
zsh ${SCR_DIR}/adjust_LRimages_mbSRR.sh ${HR_grid} ${HM_DIR} ${BM_DIR} ${LRADJ_DIR} ${BMADJ_DIR} ${FOVADJ_DIR}
# Run python script
LAMBDA=0.1
OUT_SRRpy=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRRpy.nii.gz
zsh ${SCR_DIR}/model-based_SRR_py.sh ${HRFL_INT} ${LRADJ_DIR} ${FOVADJ_DIR} ${LAMBDA} ${STORM_DIR} ${OUT_SRRpy}

# Model-based SRR with matlab code: LR images do not need to be adjuste but it takes ages!
LAMBDA=0.1
OUT_SRRmat=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRRmat.nii.gz
zsh ${SCR_DIR}/model-based_SRR_matlab.sh ${HM_DIR} ${BM_DIR} ${HRFL_INT} ${LAMBDA} ${mSRR_DIR} ${BB_DIR} ${OUT_SRRmat}

###################################################################################
# Segmentations 
epsilon=0.001
FLAIR_IM=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_seginput.nii.gz
mrcalc ${OUT_SRRpy} 0 ${epsilon} -replace ${FLAIR_IM} -force -quiet

hd-bet -i ${FLAIR_IM} -o ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
rm ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_bet.nii.gz

# SAMSEG
OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg
mkdir -p ${OUT_DIR}
run_samseg --input ${FLAIR_IM} --output ${OUT_DIR} \
--pallidum-separate --lesion --lesion-mask-pattern 1 \
--random-seed 22 --threads 8
rm ${OUT_DIR}/mode*_bias_*.mgz ${OUT_DIR}/template_coregistered.mgz
# Check unknowns within brain
mrcalc ${OUT_DIR}/seg.mgz 0 -eq ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_bet_mask.nii.gz -mult ${OUT_DIR}/unknownswithinbrain.nii.gz -datatype bit -force -quiet
mrstats ${OUT_DIR}/unknownswithinbrain.nii.gz -mask ${OUT_DIR}/unknownswithinbrain.nii.gz -quiet -output count > ${OUT_DIR}/count_unknownswithinbrain.txt

# LST
# threshold for segmentation
thLST=0.1
OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LST
mkdir -p ${OUT_DIR}
INNII=${OUT_DIR}/input.nii
mrconvert ${FLAIR_IM} ${INNII} -quiet -force
PLES=${OUT_DIR}/ples_lpa_minput.nii
matlab -nodisplay -r "addpath('$SPM_DIR'); addpath('$SEGF_DIR'); cd '$OUT_DIR'; lst_lpa('$INNII', 0); lst_lpa_voi('$PLES', '$thLST'); exit"
mrconvert ${PLES} ${OUT_DIR}/ples_lpa.nii.gz -force -quiet
mv ${OUT_DIR}/LST_tlv_${thLST}_*.csv ${OUT_DIR}/LST_lpa_${thLST}.csv
rm ${OUT_DIR}/input.nii ${OUT_DIR}/minput.nii ${OUT_DIR}/LST_lpa_minput.mat ${PLES}