#!/usr/bin/zsh

# Example Process session with fast HR FLAIR (C), and sT1 MRI
# Diana Giraldo, Nov 2022

# ANTs directory
ANTS_DIR=/opt/ANTs/bin
# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing

# DICOM dir
DCM_DIR=/home/vlab/MS_proj/DCM_imgs
# Raw MRI dir
MRI_DIR=/home/vlab/MS_proj/MS_MRI
# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI

CASE=0229128
FOLDER=5

###################################################################################
# Convert from DICOM to Nifti and put images in MRI dir for raw data
for SEQ in sT1 Flair_fast; 
do
    IN_DCM=$(ls -d ${DCM_DIR}/${CASE}/${FOLDER}/*${SEQ}*/ | head -n 1 )
    RAW_IM=$(zsh ${SCR_DIR}/scripts/convert_organize.sh ${IN_DCM} ${MRI_DIR})
    BN=${RAW_IM%.nii.gz}
    Rscript ${SCR_DIR}/scripts/dcminfo2json.R ${BN}.txt ${SCR_DIR}/data/dicomtags.csv ${BN}.json
done

###################################################################################
# Pre-process images
DATE=20160818
for SEQ in sT1 Flair_fast; 
do
    RAW_IM=$(ls ${MRI_DIR}/sub-${CASE}/ses-${DATE}/anat/*${SEQ}*.nii* | head -n 1 )
    zsh ${SCR_DIR}/scripts/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
done

###################################################################################
# Align sT1 to fast FLAIR 
REF_SEQ=Flair_fast
REF_IM=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${REF_SEQ}*_preproc.nii* | head -n 1 )
REF_MASK=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${REF_SEQ}*_brainmask.nii* | head -n 1 )
MOV_SEQ=sT1
MOV_IM=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${MOV_SEQ}*_preproc.nii* | head -n 1 )
MOV_MASK=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${MOV_SEQ}*_brainmask.nii* | head -n 1 )
OUT_PRE=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/rigreg_${MOV_SEQ}_to_${REF_SEQ}_

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
    --interpolation Linear \
    --transform ${OUT_PRE}0GenericAffine.mat

###################################################################################
# Run SAMSEG for lesion and tissue segmentation
T1_IM=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/rigreg_sT1_to_Flair_fast_transformed.nii.gz
FLAIR_IM=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*Flair_fast*_preproc.nii* | head -n 1 )
OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg
mkdir -p ${OUT_DIR}
run_samseg --input ${T1_IM} ${FLAIR_IM} --pallidum-separate --lesion --lesion-mask-pattern 0 1 --output ${OUT_DIR} --threads 8

