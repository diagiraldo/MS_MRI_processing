#!/usr/bin/zsh

# Process sessions with only fast HR FLAIR (C)
# Diana Giraldo, Dec 2022

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

###################################################################################
# List of sessions (Subject Date) to process
PP=C
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

        # Run SAMSEG for lesion and tissue segmentation
        echo "Starting SAMSEG for segmentation"
        FLAIR_IM=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*(Flair_fast|Brain_VIEW_FLAIR)*_preproc.nii* | head -n 1 )
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

# Run LST for lesion probabilistic segmentation
# SPM directory (with LST toolbox)
SPM_DIR=/home/vlab/spm12/
# Directory with matlab functions for LST
SEGF_DIR=${SCR_DIR}/scripts/LSTfunctions/
thLST=0.1

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    
    FLAIR_IM=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*(Flair_fast|Brain_VIEW_FLAIR)*_preproc.nii* | head -n 1 )
    OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LST
    mkdir -p ${OUT_DIR}
    INNII=${OUT_DIR}/input.nii
    mrconvert ${FLAIR_IM} ${INNII} -quiet -force
    PLES=${OUT_DIR}/ples_lpa_minput.nii
    matlab -nodisplay -r "addpath('$SPM_DIR'); addpath('$SEGF_DIR'); cd '$OUT_DIR'; lst_lpa('$INNII', 0); lst_lpa_voi('$PLES', '$thLST'); exit"
    mrconvert ${PLES} ${OUT_DIR}/ples_lpa.nii.gz 
    mv ${OUT_DIR}/LST_tlv_${thLST}_*.csv ${OUT_DIR}/LST_lpa_${thLST}.csv
    rm ${OUT_DIR}/input.nii ${OUT_DIR}/minput.nii ${OUT_DIR}/LST_lpa_minput.mat ${PLES}

done < ${SS_LIST}