#!/usr/bin/zsh

# Example Process session with LR FLAIR (B), fast HR FLAIR (C), and sT1 MRI
# Diana Giraldo, Nov 2022
# Last update: August 2023

# ANTs directory
ANTS_DIR=/opt/ANTs/bin
# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing/scripts
# STORM directory (for model-based SRR)
STORM_DIR=/home/vlab/STORM
# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Raw MRI dir
MRI_DIR=/home/vlab/MS_proj/MS_MRI
# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI

CASE=2400402
DATE=20170227

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
rm -r ${BM_DIR}
mkdir -p ${BM_DIR}
for IM in $(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*[Ff][Ll][Aa][Ii][Rr]*preproc.nii.gz); 
do
    SLC=$( mrinfo ${IM} -spacing -config RealignTransform 0 | cut -d" " -f3 )
    if [[ ${SLC} > ${slcth} ]]; then
        cp ${IM} ${FL_DIR}/.
        cp ${IM%_preproc.nii.gz}_brainmask.nii.gz ${BM_DIR}/.
    fi
done

# Histogram matching (between LR images)
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
# Align HR reconstructed to fast FLAIR
REF_SEQ=Flair_fast
REF_IM=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${REF_SEQ}*_preproc.nii* | head -n 1 )
REF_MASK=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${REF_SEQ}*_brainmask.nii* | head -n 1 )
MOV_IM=${OUT_SRRpy}
hd-bet -i ${MOV_IM} -o ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRR_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
MOV_MASK=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRR_bet_mask.nii.gz
OUT_PRE=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/rigreg_mbSRR_to_${REF_SEQ}_

antsRegistration --dimensionality 3 --output \[ ${OUT_PRE} \] \
    --collapse-output-transforms 1 \
    --interpolation Linear \
    --initial-moving-transform \[ ${REF_IM},${MOV_IM},1 \] \
    --metric MI\[ ${REF_IM},${MOV_IM},1,32,Regular,0.25 \] \
    --transform Rigid\[ 0.1 \] \
    --convergence \[ 1000x500x250x0,1e-6,10 \] \
    --smoothing-sigmas 3x2x1x0vox \
    --shrink-factors 8x4x2x1 \
    --use-histogram-matching 0 \
    --winsorize-image-intensities \[ 0.005,0.995 \] \
    --masks \[ ${REF_MASK},${MOV_MASK} \] \
    --float 0 \
    --verbose 0

antsApplyTransforms --dimensionality 3 \
    --input ${MOV_IM} \
    --reference-image ${REF_IM} \
    --output ${OUT_PRE}transformed.nii.gz \
    --interpolation BSpline\[ 3 \] \
    --transform ${OUT_PRE}0GenericAffine.mat