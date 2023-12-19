#!/usr/bin/zsh

# Process sessions with fast HR FLAIR (C) without sT1 MRI in SET 2 - Pelt
# Diana Giraldo, Dec 2023
# Last update: Dec 2023

# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing/scripts

# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/MS_MRI_2

###################################################################################
# List of sessions (Subject Date) to process
PP=C
SS_LIST=/home/vlab/MS_proj/info_files/subject_date_proc_${PP}__2.txt

# RE-RUN of: pre-processing

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}, Session date: ${DATE}"
    echo ""

    IM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat

    HRFLAIR=$(find ${IM_DIR}/sub-${CASE}_ses-${DATE}_*3D_Flair_fast_3D*_preproc.nii.gz)
    HRFLMASK=$(find ${IM_DIR}/sub-${CASE}_ses-${DATE}_*3D_Flair_fast_3D*_brainmask.nii.gz)

    mrcalc ${HRFLAIR} 0 -lt 0 ${HRFLAIR} -if ${HRFLAIR} -force -quiet

    # Segmentations

    epsilon=0.01    
    FLAIR_IM=${IM_DIR}/HR_FLAIR_seginput.nii.gz
    mrcalc ${HRFLAIR} 0 ${epsilon} -replace ${FLAIR_IM} -force -quiet

    # SAMSEG segmentation
    if [[ ! -f ${IM_DIR}/samseg/seg.mgz ]]; then
        echo "Starting SAMSEG for segmentation"
        OUT_DIR=${IM_DIR}/samseg
        mkdir -p ${OUT_DIR}

        run_samseg --input ${FLAIR_IM} --output ${OUT_DIR} \
        --pallidum-separate --lesion --lesion-mask-pattern 1 \
        --random-seed 22 --threads 8

        rm ${OUT_DIR}/mode*_bias_*.mgz ${OUT_DIR}/template_coregistered.mgz
        echo "Samseg segmentation done"

        mrcalc ${IM_DIR}/samseg/seg.mgz 0 -eq ${HRFLMASK} -mult ${IM_DIR}/samseg/unknownswithinbrain.nii.gz -datatype bit -force -quiet
        mrstats ${IM_DIR}/samseg/unknownswithinbrain.nii.gz -mask ${IM_DIR}/samseg/unknownswithinbrain.nii.gz -quiet -output count > ${IM_DIR}/samseg/count_unknownswithinbrain.txt

    else
        echo "Samseg segmentation already exists"
        echo ""

    fi 

    # LST segmentation

    thLST=0.1
    if [[ ! -f ${IM_DIR}/LST/ples_lpa.nii.gz ]]; then
        echo "Starting LST for lesion segmentation"
        OUT_DIR=${IM_DIR}/LST
        mkdir -p ${OUT_DIR}
        INNII=${OUT_DIR}/input.nii
        mrconvert ${FLAIR_IM} ${INNII} -quiet -force
        PLES=${OUT_DIR}/ples_lpa_minput.nii
        matlab -nodisplay -r "addpath('$SPM_DIR'); addpath('$SEGF_DIR'); cd '$OUT_DIR'; lst_lpa('$INNII', 0); lst_lpa_voi('$PLES', '$thLST'); exit"
        mrconvert ${PLES} ${OUT_DIR}/ples_lpa.nii.gz -force -quiet
        mv ${OUT_DIR}/LST_tlv_${thLST}_*.csv ${OUT_DIR}/LST_lpa_${thLST}.csv
        rm ${OUT_DIR}/input.nii ${OUT_DIR}/minput.nii ${OUT_DIR}/LST_lpa_minput.mat ${PLES}

    else
        echo "LST segmentation already exists"
        echo ""

    fi 
    
done < ${SS_LIST}


