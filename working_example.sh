#!/usr/bin/zsh

# Process MRI
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

CASE=0030403

for IN_DCM in $(ls -d ${DCM_DIR}/${CASE}/1/*FLAIR*/); 
do
    # Convert and put in folder of raw MRI
    RAW_IM=$(zsh ${SCR_DIR}/scripts/convert_organize.sh ${IN_DCM} ${MRI_DIR})
    # Convert DICOM info to .json
    BN=${RAW_IM%.nii.gz}
    Rscript ${SCR_DIR}/scripts/dcminfo2json.R ${BN}.txt ${SCR_DIR}/data/dicomtags.csv ${BN}.json
    # Pre-process image (Denoise and N4), save it in folder of processed data
    zsh ${SCR_DIR}/scripts/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
done

DATE=$(ls ${PRO_DIR}/sub-${CASE} | head -n 1 | cut -d"-" -f2 )

FL_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/FLAIR_preproc
mkdir -p ${FL_DIR}
mv ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*FLAIR*preproc.nii.gz ${FL_DIR}/.

# Intensity normalisation - histogram matching
HM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/FLAIR_hmatch
zsh ${SCR_DIR}/scripts/histmatch_folder.sh ${FL_DIR} ${HM_DIR}

# Interpolation (can be then used to initialize model-based SRR)
# Reference image grid
REF_IM=$(ls ${HM_DIR}/sub-*_ses-*_*TRA_*.nii* | head -n 1 )
ISOVOX=$(mrinfo ${REF_IM} -spacing | awk '{print $1}' )
HR_grid=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HRgrid_FLAIR.nii
mrgrid ${REF_IM} regrid -vox ${ISOVOX} ${HR_grid} -interp nearest -force

N_IT=4
OP_INTERP=cubic
HRFL_INT=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_interp.nii.gz
zsh ${SCR_DIR}/scripts/mSR_interpolation.sh ${HM_DIR} ${HR_grid} ${OP_INTERP} ${N_IT} ${HRFL_INT}



