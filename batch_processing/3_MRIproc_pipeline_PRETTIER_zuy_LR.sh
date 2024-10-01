#!/usr/bin/zsh

# Process sessions with LR FLAIR (acquisition) in Zuyderland using PRETTIER outputs
# Run locally

# Processing repo directory
export PYTHONPATH=/home/vlab/mrtrix3/lib:$PYTHONPATH
MYTK_DIR=/home/vlab/mri_toolkit

SCR_DIR=/home/vlab/MS_MRI_processing/scripts

# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Directory with PRETTIER outputs 
SERVDIR=/home/vlab/astra-tesla/ZUY_LR_FLAIR
# Project dir with processed data
PRO_DIR=/home/vlab/MS_proj

#################################################################################
# Loop

for SR_DIR in $(ls -d ${SERVDIR}/sub*/*/anat/LR_FLAIR_prettier);
do
    echo "--------------------------------------------------------"
    echo "${SR_DIR}"

    SESF=$(dirname $(dirname ${SR_DIR}))
    SESFN=$(basename ${SESF})
    SUBFN=$(basename $(dirname ${SESF}))

    n_IM=$(ls ${SR_DIR}/*.nii.gz | wc -l)

    if [[ ${n_IM} -lt 2 ]];
    then
        echo "less than 2 images"
        #continue
    else
        echo "2 or more images in ${SR_DIR}"
        #continue
    fi

    # Find HR grid
    HR_grid=$(find ${PRO_DIR}/*/${SUBFN}/${SESFN}/anat -type f -name "HRgrid_1mm.nii.gz" | head -n 1)
    echo "${HR_grid}"

    # Local directory
    IMDIR=$(dirname ${HR_grid})

    if [[ ! -f ${IMDIR}/HR_FLAIR_combined_prettierEDSR.nii.gz ]]; then

         
        if [[ ${n_IM} -ge 2 ]];
        then
            # Make brain masks for PRETTIER outputs
            mkdir -p ${IMDIR}/LR_FLAIR_prettier_masks
            for IM in $(ls ${SR_DIR}/*.nii.gz);
            do
                IM_BN=$(basename ${IM} | sed 's/.nii.gz//')
                hd-bet -i ${IM} -o ${IMDIR}/LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz -device cpu -mode fast -tta 0 #> /dev/null
                rm ${IMDIR}/LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz
                mv ${IMDIR}/LR_FLAIR_prettier_masks/${IM_BN}_bet_mask.nii.gz ${IMDIR}/LR_FLAIR_prettier_masks/${IM_BN}_brainmask.nii.gz
            done

            # Align and combine PRETTIER outputs
            ${MYTK_DIR}/align_combine_mrtrix3.py $(ls ${SR_DIR}/*.nii.gz) ${HR_grid} ${IMDIR}/HR_FLAIR_combined_prettierEDSR.nii.gz -masks $(ls ${IMDIR}/LR_FLAIR_prettier_masks/*.nii.gz) -iter 2 -force

            # Clean
            rm -r ${IMDIR}/LR_FLAIR_prettier_masks

        else
            rm ${IMDIR}/HR_FLAIR_prettierEDSR_brainmask.nii.gz 
            IM=$(ls ${SR_DIR}/*.nii.gz | head -n 1)
            mrgrid ${IM} regrid ${IMDIR}/HR_FLAIR_combined_prettierEDSR.nii.gz -template ${HR_grid} -force
        fi


    else
        echo "${IMDIR}/HR_FLAIR_combined_prettierEDSR.nii.gz already exists"
        #echo ""
    fi

    # Prepare for segmentation
    HRFLAIR=${IMDIR}/HR_FLAIR_combined_prettierEDSR.nii.gz
    
    if [[ ! -f ${IMDIR}/prettier_LST/ples_lpa.nii.gz || ! -f ${IMDIR}/prettier_samseg/seg.mgz ]]; then
        #${MYTK_DIR}/reorient_RAS.py --input ${HRFLAIR} --output ${HRFLAIR}
        epsilon=0.01    
        FLAIR_IM=${IMDIR}/HR_FLAIR_seginput.nii.gz
        mrcalc ${HRFLAIR} ${epsilon} -le ${epsilon} ${HRFLAIR} -if ${FLAIR_IM} -force -quiet
        #${MYTK_DIR}/reorient_RAS.py --input ${FLAIR_IM} --output ${FLAIR_IM}
    else
        echo "Segmentations with prettier MRI already exist"
        continue
    fi

    # LST segmentation
    thLST=0.1
    if [[ ! -f ${IMDIR}/prettier_LST/ples_lpa.nii.gz ]]; then
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
        echo "LST segmentation with prettier MRI already exists"
        #echo ""

    fi

    HRFLMASK=${IMDIR}/HR_FLAIR_prettierEDSR_brainmask.nii.gz

    if [[ ! -f ${HRFLMASK} ]]; then
        hd-bet -i ${HRFLAIR} -o ${IMDIR}/HR_FLAIR_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
        rm ${IMDIR}/HR_FLAIR_bet.nii.gz
        mv ${IMDIR}/HR_FLAIR_bet_mask.nii.gz ${HRFLMASK}
    fi

    # SAMSEG segmentation
    if [[ ! -f ${IMDIR}/prettier_samseg/seg.mgz ]]; then
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

done