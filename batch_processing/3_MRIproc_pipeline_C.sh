#!/usr/bin/zsh

# Process sessions with only fast HR FLAIR (C)
# Diana Giraldo, Dec 2022
# Last update: September 2023

# ANTs directory
ANTS_DIR=/opt/ANTs/bin
# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing/scripts

# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Raw MRI dir
MRI_DIR=/home/vlab/MS_proj/MS_MRI
# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI

###################################################################################
# List of sessions (Subject Date) to process
PP=C
SS_LIST=/home/vlab/MS_proj/info_files/subject_date_proc_${PP}.txt

# BEFORE Re-running pipeline, move previous segmentation results
while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    echo " "

    if [[ -d  ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg ]];
    then
        echo 'previous SAMSEG folder exists'
        mv ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/prev_samseg
    fi

    if [[ -d  ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LST ]];
    then
        echo 'previous LST folder exists'
        mv ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LST ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/prev_LST
    fi

done < ${SS_LIST}

# RE-RUN of: pre-processing

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    echo ""

    # Pre-process images
    echo "Starting pre-processing"
    for RAW_IM in $(ls ${MRI_DIR}/sub-${CASE}/ses-${DATE}/anat/*(sT1|[Ff][Ll][Aa][Ii][Rr])*.nii*);
    do
        zsh ${SCR_DIR}/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
    done
    echo "Pre-processing done"
    echo ""

done < ${SS_LIST}

####################################################################
# RE-RUN of: segmentations

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    echo ""

    OUT_HRFLAIR=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*(Flair_fast|Brain_VIEW_FLAIR)*_preproc.nii* | head -n 1 )
    FLAIR_IM=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_seginput.nii.gz

    # Segmentations

    if [[ ! -f ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg/seg.mgz ]]; then

        if [[ ! -f ${FLAIR_IM} ]];
        then
            epsilon=0.01
            mrcalc ${OUT_HRFLAIR} 0 ${epsilon} -replace ${FLAIR_IM} -force -quiet
        fi

        # Run SAMSEG for lesion and tissue segmentation
        echo "Starting SAMSEG for segmentation"
        OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg
        mkdir -p ${OUT_DIR}
        run_samseg --input ${FLAIR_IM} --output ${OUT_DIR} \
        --pallidum-separate --lesion --lesion-mask-pattern 1 \
        --random-seed 22 --threads 8
        rm ${OUT_DIR}/mode*_bias_*.mgz ${OUT_DIR}/template_coregistered.mgz
        echo "Samseg segmentation done"
        # Check unknowns within brain
        if [[ ! -f ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_bet_mask.nii.gz ]];
        then
            hd-bet -i ${FLAIR_IM} -o ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
            rm ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_bet.nii.gz
        fi 
        mrcalc ${OUT_DIR}/seg.mgz 0 -eq ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_bet_mask.nii.gz -mult ${OUT_DIR}/unknownswithinbrain.nii.gz -datatype bit -force -quiet
        mrstats ${OUT_DIR}/unknownswithinbrain.nii.gz -mask ${OUT_DIR}/unknownswithinbrain.nii.gz -quiet -output count > ${OUT_DIR}/count_unknownswithinbrain.txt

    else

        echo "Samseg segmentation already exists"
        echo ""

    fi      

done < ${SS_LIST}

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    echo ""

    OUT_HRFLAIR=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*(Flair_fast|Brain_VIEW_FLAIR)*_preproc.nii* | head -n 1 )

    # Run LST
    echo "Starting LST for lesion segmentation"
    thLST=0.1
    OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LST
    mkdir -p ${OUT_DIR}
    INNII=${OUT_DIR}/input.nii
    mrconvert ${OUT_HRFLAIR} ${INNII} -quiet -force
    PLES=${OUT_DIR}/ples_lpa_minput.nii
    matlab -nodisplay -r "addpath('$SPM_DIR'); addpath('$SEGF_DIR'); cd '$OUT_DIR'; lst_lpa('$INNII', 0); lst_lpa_voi('$PLES', '$thLST'); exit"
    mrconvert ${PLES} ${OUT_DIR}/ples_lpa.nii.gz -force -quiet
    mv ${OUT_DIR}/LST_tlv_${thLST}_*.csv ${OUT_DIR}/LST_lpa_${thLST}.csv
    rm ${OUT_DIR}/input.nii ${OUT_DIR}/minput.nii ${OUT_DIR}/LST_lpa_minput.mat ${PLES}
    
done < ${SS_LIST}