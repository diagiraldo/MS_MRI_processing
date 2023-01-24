#!/usr/bin/zsh

# Process sessions with LR FLAIR acquired with protocol (B)
# Diana Giraldo, Dec 2022

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

###################################################################################
# List of sessions (Subject Date) to process
PP=B
SS_LIST=/home/vlab/MS_proj/info_files/subject_date_proc_${PP}.txt

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    echo "-----------------------------------------"

    if [[ ! -f ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg/seg.mgz ]]; then

        # Pre-process images
        echo "Starting pre-processing"
        for RAW_IM in $(ls ${MRI_DIR}/sub-${CASE}/ses-${DATE}/anat/*(sT1|[Ff][Ll][Aa][Ii][Rr])*.nii*);
        do
            zsh ${SCR_DIR}/scripts/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
        done
        echo "Pre-processing done"

        # Use available LR FLAIR to obtain a HR image
        echo "Starting Super Resolution Reconstruction"
        slcth=2
        # Copy LR FLAIR (and masks) to subfolders
        FL_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_preproc
        BM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_masks
        mkdir -p ${FL_DIR} ${BM_DIR}
        for IM in $(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*[Ff][Ll][Aa][Ii][Rr]*preproc.nii.gz); 
        do
            SLC=$( mrinfo ${IM} -spacing | cut -d" " -f3 )
            if [[ ${SLC} > ${slcth} ]]; then
                cp ${IM} ${FL_DIR}/.
                cp ${IM%_preproc.nii.gz}_brainmask.nii.gz ${BM_DIR}/.
            fi
        done
        # Histogram matching
        HM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_hmatch
        zsh ${SCR_DIR}/scripts/histmatch_folder.sh ${FL_DIR} ${BM_DIR} ${HM_DIR}
        rm -r ${FL_DIR}
        # Grid template
        REF_IM=$(ls ${HM_DIR}/sub-*_ses-*_*TRA_*.nii* | head -n 1 )
        ISOVOX=1
        HR_grid=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HRgrid_FLAIR.nii.gz
        mrgrid ${REF_IM} pad -axis 2 1,1 - -quiet | mrgrid - regrid -vox ${ISOVOX} ${HR_grid} -interp nearest -force -quiet
        # Interpolation
        N_IT=4
        OP_INTERP=cubic
        HRFL_INT=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_interp.nii.gz
        zsh ${SCR_DIR}/scripts/mSR_interpolation.sh ${HM_DIR} ${BM_DIR} ${HR_grid} ${OP_INTERP} ${N_IT} ${HRFL_INT}
        rm ${HR_grid}
        # Model-based SRR
        LAMBDA=0.1
        HRFL_SRR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRR.nii.gz
        zsh ${SCR_DIR}/scripts/model-based_SRR.sh ${HM_DIR} ${BM_DIR} ${HRFL_INT} ${LAMBDA} ${mSRR_DIR} ${BB_DIR} ${HRFL_SRR}
        echo "Super Resolution Reconstruction done"

        # Run SAMSEG for lesion and tissue segmentation
        echo "Starting SAMSEG for segmentation"
        FLAIR_IM=${HRFL_SRR}
        OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg
        mkdir -p ${OUT_DIR}
        run_samseg --input ${FLAIR_IM} --pallidum-separate --lesion --lesion-mask-pattern 1 --output ${OUT_DIR} --threads 8
        rm ${OUT_DIR}/mode*_bias_*.mgz ${OUT_DIR}/template_coregistered.mgz
        echo "Segmentation done"
    
    else

        echo "Segmentation already exists"

    fi

    echo "-----------------------------------------"

done < ${SS_LIST}

# Visual Check
i=1
CASE=$( cat ${SS_LIST} | head -n ${i} | tail -1 | awk '{print $1}')
DATE=$( cat ${SS_LIST} | head -n ${i} | tail -1 | awk '{print $2}')
FLAIR_IM=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRR.nii.gz
mrview ${FLAIR_IM} -overlay.load ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg/seg.mgz -mode 2 -size 1600,900 -overlay.opacity 0.75 -overlay.colourmap 4 -overlay.intensity 0,100 -overlay.threshold_max 100 -overlay.interpolation 0