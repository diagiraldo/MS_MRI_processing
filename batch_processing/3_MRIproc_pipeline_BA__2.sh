#!/usr/bin/zsh

# Process sessions with LR FLAIR (acquisition B) in SET 2 - Pelt
# Diana Giraldo, Dec 2023
# Last update: Dec 2023

# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing/scripts

# STORM directory for model-based SRR in python
STORM_DIR=/home/vlab/STORM

# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/MS_MRI_2

###################################################################################
# List of sessions (Subject Date) to process
PP=A
SS_LIST=/home/vlab/MS_proj/info_files/subject_date_proc_${PP}__2.txt

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}, Session date: ${DATE}"
    echo ""

    IM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat
    OUT_SRRpy=${IM_DIR}/HR_FLAIR_mbSRRpy.nii.gz

    if [[ ! -f ${OUT_SRRpy} ]]; then

        # Copy LR FLAIR (and masks) to subfolders
        FL_DIR=${IM_DIR}/LR_FLAIR_preproc
        BM_DIR=${IM_DIR}/LR_FLAIR_masks
        mkdir -p ${FL_DIR} ${BM_DIR}

        for IM in $(ls ${IM_DIR}/*FLAIR*_preproc.nii.gz); 
        do
            IMBN=$(basename ${IM})
            cp ${IM} ${FL_DIR}/.
            cp ${IM%_preproc.nii.gz}_brainmask.nii.gz ${BM_DIR}/.
        done

        # Histogram matching
        HM_DIR=${IM_DIR}/LR_FLAIR_hmatch
        zsh ${SCR_DIR}/histmatch_folder.sh ${FL_DIR} ${BM_DIR} ${HM_DIR}
        echo "Histogram matching done"
        echo ""

        # Grid template
        ISOVOX=1
        HR_grid=${IM_DIR}/HRgrid_${ISOVOX}mm.nii.gz
        zsh ${SCR_DIR}/get_HRgrid.sh ${BM_DIR} ${ISOVOX} ${HR_grid}
        echo "HR grid template in ${HR_grid}"
        echo ""

        # FIRST: Interpolation
        N_IT=4
        OP_INTERP=cubic
        HRFL_INT=${IM_DIR}/HR_FLAIR_interp.nii.gz
        zsh ${SCR_DIR}/mSR_interpolation.sh ${HM_DIR} ${BM_DIR} ${HR_grid} ${OP_INTERP} ${N_IT} ${HRFL_INT}
        echo "Interpolated HR image in ${HRFL_INT}"
        echo ""

        # SECOND: Model-based SRR using python script
        # Adjust LR images
        LRADJ_DIR=${IM_DIR}/LR_FLAIR_adjusted
        BMADJ_DIR=${IM_DIR}/LR_MASK_adjusted
        FOVADJ_DIR=${IM_DIR}/LR_FOV_adjusted
        zsh ${SCR_DIR}/adjust_LRimages_mbSRR.sh ${HR_grid} ${HM_DIR} ${BM_DIR} ${LRADJ_DIR} ${BMADJ_DIR} ${FOVADJ_DIR}
        # Run python script
        LAMBDA=0.1
        zsh ${SCR_DIR}/model-based_SRR_py.sh ${HRFL_INT} ${LRADJ_DIR} ${FOVADJ_DIR} ${LAMBDA} ${STORM_DIR} ${OUT_SRRpy}
        echo "Output of model-based SRR in ${OUT_SRRpy}"
        echo ""

        # Clean
        rm -r ${FL_DIR} ${HM_DIR} ${BM_DIR} ${LRADJ_DIR} ${BMADJ_DIR} ${FOVADJ_DIR} 

    else
        echo "Output of model-based SRR already exists in ${OUT_SRRpy}"
        echo ""
    fi

    HRFLAIR=${OUT_SRRpy}
    echo "Input HR FLAIR: ${HRFLAIR}"

    # Brain mask
    HRFLMASK=${IM_DIR}/HR_FLAIR_mbSRRpy_brainmask.nii.gz   
    if [[ ! -f ${HRFLMASK} ]];
    then
        hd-bet -i ${HRFLAIR} -o ${IM_DIR}/HR_FLAIR_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
        rm ${IM_DIR}/HR_FLAIR_bet.nii.gz
        mv ${IM_DIR}/HR_FLAIR_bet_mask.nii.gz ${HRFLMASK}
    fi

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