#!/usr/bin/zsh

# Process sessions with ONLY ONE LR FLAIR (acquisition) in Zuyderland using PRETTIER as SR
# Run locally

# Processing repo directory
MYTK_DIR=/home/vlab/mri_toolkit

SCR_DIR=/home/vlab/MS_MRI_processing/scripts
# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Project dir with processed data
PRO_DIR=/home/vlab/MS_proj/processed_MRI_zuy

# List of sessions with LR FLAIR
SESS_LIST=/home/vlab/MS_proj/info_files/sessions_zuy_proc_no_proc.txt 

while IFS= read -r line;
do
    SUB=$(echo $line | awk '{print $1}')
    SESS=$(echo $line | awk '{print $2}')

    IMDIR=${PRO_DIR}/sub-${SUB}/ses-${SESS}/anat

    echo "-----------------------------------------"
    IM=$(ls ${IMDIR}/*FLAIR_preproc.nii.gz | head -n 1)
    IM_BN=$(basename ${IM} | sed 's/_preproc.nii.gz//')
    echo ${IM}

    if [[ ! -f ${IMDIR}/HR_FLAIR_regrid_prettierEDSR.nii.gz ]]; 
    then
        
        # Grid template
        ISOVOX=1
        HR_grid=${IMDIR}/HRgrid_${ISOVOX}mm.nii.gz
        if [[ ! -f ${HR_grid} ]]; 
        then
            # Copy LR mask to subfolders
            BM_DIR=${IMDIR}/LR_FLAIR_masks
            mkdir -p ${BM_DIR}
            cp ${IM%_preproc.nii.gz}_brainmask.nii.gz ${BM_DIR}/${IM_BN}_TRA_brainmask.nii.gz
            cp ${IM%_preproc.nii.gz}.json ${IM%_preproc.nii.gz}_TRA.json
            # Make grid
            zsh ${SCR_DIR}/get_HRgrid.sh ${BM_DIR} ${ISOVOX} ${HR_grid}
            echo "HR grid template in ${HR_grid}"
            # Clean
            rm -r ${BM_DIR}
        fi
        
        # Run prettier 
        if [[ ! -f ${IMDIR}/${IM_BN}_prettierEDSR.nii.gz ]]; 
        then
            echo "${IMDIR}/${IM_BN}_prettierEDSR.nii.gz doesn't exists"
            ~/PRETTIER/prettier_mri.py --input ${IM} --model-name EDSR --output ${IMDIR}/${IM_BN}_prettierEDSR.nii.gz --batch-size 6 --gpu-id 0
        else
            echo "${IMDIR}/${IM_BN}_prettierEDSR.nii.gz"
        fi

        # Regrid and reorient
        mrgrid ${IMDIR}/${IM_BN}_prettierEDSR.nii.gz regrid ${IMDIR}/HR_FLAIR_regrid_prettierEDSR.nii.gz -template ${HR_grid} -force
        #${MYTK_DIR}/reorient_RAS.py --input ${IMDIR}/HR_FLAIR_regrid_prettierEDSR.nii.gz --output ${IMDIR}/HR_FLAIR_regrid_prettierEDSR.nii.gz
    else
        echo "${IMDIR}/HR_FLAIR_regrid_prettierEDSR.nii.gz already exists"
    fi    

    # Prepare for segmentation
    HRFLAIR=${IMDIR}/HR_FLAIR_regrid_prettierEDSR.nii.gz
    HRFLMASK=${IMDIR}/HR_FLAIR_prettierEDSR_brainmask.nii.gz 

    if [[ ! -f ${HRFLMASK} ]]; then
        hd-bet -i ${HRFLAIR} -o ${IMDIR}/HR_FLAIR_bet.nii.gz -device cpu -mode fast -tta 0 
        rm ${IMDIR}/HR_FLAIR_bet.nii.gz
        mv ${IMDIR}/HR_FLAIR_bet_mask.nii.gz ${HRFLMASK}
    fi

    if [[ ! -f ${IMDIR}/prettier_LST/ples_lpa.nii.gz || ! -f ${IMDIR}/prettier_samseg/seg.mgz ]]; then
        epsilon=0.01    
        FLAIR_IM=${IMDIR}/HR_FLAIR_seginput.nii.gz
        mrcalc ${HRFLAIR} ${epsilon} -le ${epsilon} ${HRFLAIR} -if ${FLAIR_IM} -force -quiet
    else
        echo "Segmentations with prettier MRI already exist"
        continue
    fi

    # LST segmentation
    thLST=0.1
    n_failedlst=$(ls ${IMDIR}/prettier_LST/LST_log_*.txt | wc -l)
    if [[ ! -f ${IMDIR}/prettier_LST/ples_lpa.nii.gz && ${n_failedlst} -lt 1 ]]; then
        echo "LST segmentation with prettier MRI doesn't exist"
        echo "Starting LST for lesion segmentation"
        OUT_DIR=${IMDIR}/prettier_LST
        mkdir -p ${OUT_DIR}
        INNII=${OUT_DIR}/input.nii
        mrconvert ${FLAIR_IM} ${INNII} -quiet -force
        PLES=${OUT_DIR}/ples_lpa_minput.nii
        matlab -nodisplay -r "addpath('$SPM_DIR'); addpath('$SEGF_DIR'); cd '$OUT_DIR'; lst_lpa('$INNII', 0); lst_lpa_voi('$PLES', '$thLST'); exit"
        mrconvert ${PLES} ${OUT_DIR}/ples_lpa.nii.gz -force -quiet
        mv ${OUT_DIR}/LST_tlv_${thLST}_*.csv ${OUT_DIR}/LST_lpa_${thLST}.csv
        rm ${OUT_DIR}/input.nii ${OUT_DIR}/minput.nii ${OUT_DIR}/LST_lpa_minput.mat ${PLES}
        
    else
        echo "LST segmentation with prettier MRI already exists or it has prevously failed"

    fi

    # SAMSEG segmentation
    if [[ ! -f ${IMDIR}/prettier_samseg/seg.mgz ]]; then

        echo "Samseg segmentation with prettier MRI doesn't exist"
        echo "Starting SAMSEG for segmentation"
        OUT_DIR=${IMDIR}/prettier_samseg
        mkdir -p ${OUT_DIR}

        run_samseg --input ${FLAIR_IM} --output ${OUT_DIR} \
        --pallidum-separate --lesion --lesion-mask-pattern 1 --threshold 0.1 \
        --random-seed 22 --threads 8

        rm ${OUT_DIR}/mode*_bias_*.mgz ${OUT_DIR}/template_coregistered.mgz
        echo "Samseg segmentation done"

        mrcalc ${OUT_DIR}/seg.mgz 0 -eq ${HRFLMASK} -mult ${OUT_DIR}/unknownswithinbrain.nii.gz -datatype bit -force -quiet
        mrstats ${OUT_DIR}/unknownswithinbrain.nii.gz -mask ${OUT_DIR}/unknownswithinbrain.nii.gz -quiet -output count > ${OUT_DIR}/count_unknownswithinbrain.txt

    else
        echo "Samseg segmentation with prettier MRI already exists"
        #echo ""

    fi 

    # Clean
    rm ${IMDIR}/HR_FLAIR_seginput.nii.gz


done < ${SESS_LIST}
