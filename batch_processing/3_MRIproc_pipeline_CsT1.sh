#!/usr/bin/zsh

# Process sessions with fast HR FLAIR (C), and sT1 MRI
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
PP=CsT1
SS_LIST=/home/vlab/MS_proj/info_files/subject_date_proc_${PP}.txt

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
    for SEQ in sT1 Flair_fast; 
    do
        RAW_IM=$(ls ${MRI_DIR}/sub-${CASE}/ses-${DATE}/anat/*${SEQ}*.nii* | head -n 1 )
        zsh ${SCR_DIR}/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
    done
    echo "Pre-processing done"
    echo ""

    # Align sT1 to fast FLAIR
    REF_SEQ=Flair_fast
    MOV_SEQ=sT1 
    echo "Starting rigid registration of ${MOV_SEQ} to ${REF_SEQ}"

    REF_IM=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${REF_SEQ}*_preproc.nii* | head -n 1 )
    REF_MASK=$(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*${REF_SEQ}*_brainmask.nii* | head -n 1 )
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
        --interpolation BSpline \
        --transform ${OUT_PRE}0GenericAffine.mat

    mrcalc ${OUT_PRE}transformed.nii.gz 0 -lt 0 ${OUT_PRE}transformed.nii.gz -if ${OUT_PRE}transformed.nii.gz -force -quiet
    echo "Alignment done"
    echo "Aligned T1: ${OUT_PRE}transformed.nii.gz"
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
    OUT_HRT1=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/rigreg_sT1_to_Flair_fast_transformed.nii.gz
    
    epsilon=0.01
    FLAIR_IM=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_seginput.nii.gz
    T1_IM=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_T1_seginput.nii.gz

    # Segmentations

    if [[ ! -f ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg/seg.mgz ]]; then

        if [[ ! -f ${FLAIR_IM} ]];
        then
            mrcalc ${OUT_HRFLAIR} 0 ${epsilon} -replace ${FLAIR_IM} -force -quiet
            mrcalc ${OUT_HRT1} 0 ${epsilon} -replace ${T1_IM} -force -quiet
        fi

        # Run SAMSEG for lesion and tissue segmentation
        echo "Starting SAMSEG for segmentation"
        OUT_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/samseg
        mkdir -p ${OUT_DIR}
        run_samseg --input ${T1_IM} ${FLAIR_IM} --output ${OUT_DIR} \
        --pallidum-separate --lesion --lesion-mask-pattern 0 1 \
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

    if [[ ! -f ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LST/ples_lpa.nii.gz ]]; then

        if [[ ! -f ${FLAIR_IM} ]];
        then
            mrcalc ${OUT_HRFLAIR} 0 ${epsilon} -replace ${FLAIR_IM} -force -quiet
        fi

        # Run LST
        echo "Starting LST for lesion segmentation"
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
    
    else

        echo "LST lesion segmentation already exists"
        echo ""

    fi       

done < ${SS_LIST}
