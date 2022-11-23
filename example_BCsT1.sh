#!/usr/bin/zsh

# Example Process session with LR FLAIR (B), fast HR FLAIR (C), and sT1 MRI
# Diana Giraldo, Nov 2022

# ANTs directory
ANTS_DIR=/opt/ANTs/bin
# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing

# Code and dependencies for model-based SRR
SR_DIR=/home/vlab/SR_MS_eval
# SRR directory
mSRR_DIR=${SR_DIR}/ModelBasedSRR
# Dependencies directory
BB_DIR=${SR_DIR}/BuildingBlocks

# DICOM dir
DCM_DIR=/home/vlab/MS_proj/DCM_imgs
# Raw MRI dir
MRI_DIR=/home/vlab/MS_proj/MS_MRI
# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI

CASE=2400402
FOLDER=2

################################################################################
#
# Convert and pre-process FLAIR and structural T1 in folder
#
for IN_DCM in $(ls -d ${DCM_DIR}/${CASE}/${FOLDER}/*(sT1|[Ff][Ll][Aa][Ii][Rr])*/); 
do
    # Convert and put in folder of raw MRI
    RAW_IM=$(zsh ${SCR_DIR}/scripts/convert_organize.sh ${IN_DCM} ${MRI_DIR})
    # Convert DICOM info to .json
    BN=${RAW_IM%.nii.gz}
    Rscript ${SCR_DIR}/scripts/dcminfo2json.R ${BN}.txt ${SCR_DIR}/data/dicomtags.csv ${BN}.json
    # Pre-process image (Denoise and N4), save it in folder of processed data
    zsh ${SCR_DIR}/scripts/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
done
#
################################################################################
#
# Use available LR FLAIR to obtain a HR image
#
DATE=$(ls ${PRO_DIR}/sub-${CASE} | head -n 1 | cut -d"-" -f2 )
# Move LR FLAIR to folder
slcth=2
FL_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_preproc
mkdir -p ${FL_DIR}
for IM in $(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*[Ff][Ll][Aa][Ii][Rr]*preproc.nii.gz); 
do
    SLC=$( mrinfo ${IM} -spacing | cut -d" " -f3 )
    if [[ ${SLC} > ${slcth} ]]; then
        cp ${IM} ${FL_DIR}/.
    fi
done
# Histogram matching
HM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_hmatch
zsh ${SCR_DIR}/scripts/histmatch_folder.sh ${FL_DIR} ${HM_DIR}
rm -r ${FL_DIR}
# Grid Template
REF_IM=$(ls ${HM_DIR}/sub-*_ses-*_*TRA_*.nii* | head -n 1 )
ISOVOX=$(mrinfo ${REF_IM} -spacing | awk '{print $1}' )
HR_grid=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HRgrid_FLAIR.nii
mrgrid ${REF_IM} regrid -vox ${ISOVOX} ${HR_grid} -interp nearest -force
# Interpolation
N_IT=4
OP_INTERP=cubic
HRFL_INT=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_interp.nii.gz
zsh ${SCR_DIR}/scripts/mSR_interpolation.sh ${HM_DIR} ${HR_grid} ${OP_INTERP} ${N_IT} ${HRFL_INT}
# Model-based SRR

#
################################################################################
#
# Align FLAIR and T1