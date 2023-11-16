#!/usr/bin/zsh

# Convert and process (SRR -> segment) LR FLAIR in MRI_Zuyderland dataset
# Diana Giraldo, Nov 2023
# Last update: Nov 2023

# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing/scripts

# STORM directory for model-based SRR in python
STORM_DIR=/home/vlab/STORM

# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI_zuy

# List of sessions with LR FLAIR
SESS_LIST=/home/vlab/MS_proj/info_files/sessions_zuy_proc_LR_FLAIR.txt 

while IFS= read -r line;
do
    SUB=$(echo $line | awk '{print $1}')
    SESS=$(echo $line | awk '{print $2}')

    IM_DIR=${PRO_DIR}/sub-${SUB}/ses-${SESS}/anat

    echo "-----------------------------------------"
    # model-based SRR with Python implementation

    OUT_SRRpy=${IM_DIR}/HR_FLAIR_mbSRRpy.nii.gz

    if [[ ! -f ${OUT_SRRpy} ]]; then

        # Copy LR FLAIR (and masks) to subfolders
        FL_DIR=${IM_DIR}/LR_FLAIR_preproc
        BM_DIR=${IM_DIR}/LR_FLAIR_masks
        mkdir -p ${FL_DIR} ${BM_DIR}
        for IM in $(ls ${IM_DIR}/*FLAIR_preproc.nii.gz); 
        do
            ORI=$(${SCR_DIR}/get_orient_nifti.py --input ${IM})
            IMBN=$(basename ${IM})
            cp ${IM} ${FL_DIR}/${IMBN%_preproc.nii.gz}_${ORI}_preproc.nii.gz
            cp ${IM%_preproc.nii.gz}_brainmask.nii.gz ${BM_DIR}/${IMBN%_preproc.nii.gz}_${ORI}_brainmask.nii.gz
            cp ${IM%_preproc.nii.gz}.json ${IM%_preproc.nii.gz}_${ORI}.json
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

        # Interpolation
        N_IT=4
        OP_INTERP=cubic
        HRFL_INT=${IM_DIR}/HR_FLAIR_interp.nii.gz
        zsh ${SCR_DIR}/mSR_interpolation.sh ${HM_DIR} ${BM_DIR} ${HR_grid} ${OP_INTERP} ${N_IT} ${HRFL_INT}
        echo "Interpolated HR image in ${HRFL_INT}"
        echo ""

        # Model-based SRR with python code
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

    HRFLMASK=${IM_DIR}/HR_FLAIR_mbSRRpy_brainmask.nii.gz   
    if [[ ! -f ${HRFLMASK} ]];
    then
        hd-bet -i ${HRFLAIR} -o ${IM_DIR}/HR_FLAIR_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
        rm ${IM_DIR}/HR_FLAIR_bet.nii.gz
        mv ${IM_DIR}/HR_FLAIR_bet_mask.nii.gz ${HRFLMASK}
    fi 

    # Look for T1W
    nT1=$(find ${IM_DIR} -name "sub-${SUB}_ses-${SESS}_*__T1W_preproc.nii.gz" -type f | wc -l)
    if [ $nT1 -eq 0 ]; then
        echo "No T1W"

    else

        HRT1=$(find ${IM_DIR}/sub-${SUB}_ses-${SESS}_*__T1W_preproc.nii.gz)
        HRT1MASK=$(find ${IM_DIR}/sub-${SUB}_ses-${SESS}_*__T1W_brainmask.nii.gz)
        echo "Input HR T1W: ${HRT1}"

        # Align T1W to FLAIR
        OUT_PRE=${IM_DIR}/rigreg_T1W_to_FLAIR_

        if [[ ! -f ${OUT_PRE}transformed.nii.gz ]]; then
            antsRegistration --dimensionality 3 --output \[ ${OUT_PRE} \] \
            --collapse-output-transforms 1 \
            --interpolation Linear \
            --initial-moving-transform \[ ${HRFLAIR},${HRT1},1 \] \
            --metric MI\[ ${HRFLAIR},${HRT1},1,32,Regular,0.25 \] \
            --transform Rigid\[ 0.1 \] \
            --convergence \[ 1000x500x250x0,1e-6,10 \] \
            --smoothing-sigmas 3x2x1x0vox \
            --shrink-factors 8x4x2x1 \
            --use-histogram-matching 0 \
            --winsorize-image-intensities \[ 0.005,0.995 \] \
            --masks \[ ${HRFLMASK},${HRT1MASK} \] \
            --float 0 \
            --verbose 0

            antsApplyTransforms --dimensionality 3 \
            --input ${HRT1} \
            --reference-image ${HRFLAIR} \
            --output ${OUT_PRE}transformed.nii.gz \
            --interpolation BSpline \
            --transform ${OUT_PRE}0GenericAffine.mat

            mrcalc ${OUT_PRE}transformed.nii.gz 0 -lt 0 ${OUT_PRE}transformed.nii.gz -if ${OUT_PRE}transformed.nii.gz -force -quiet

        else
            echo "T1 aligned to FLAIR already exists"

        fi
    fi

    # SAMSEG segmentation

    epsilon=0.01    
    FLAIR_IM=${IM_DIR}/HR_FLAIR_seginput.nii.gz
    if [[ $nT1 -gt 0 ]]; then
        T1_IM=${IM_DIR}/HR_T1_seginput.nii.gz
    fi  

    if [[ ! -f ${IM_DIR}/samseg/seg.mgz ]]; then

        if [[ ! -f ${FLAIR_IM} ]];
        then
            mrcalc ${HRFLAIR} 0 ${epsilon} -replace ${FLAIR_IM} -force -quiet
        fi

        if [[ $nT1 -gt 0 && ! -f ${T1_IM} ]];
        then
            mrcalc ${IM_DIR}/rigreg_T1W_to_FLAIR_transformed.nii.gz 0 ${epsilon} -replace ${T1_IM} -force -quiet
        fi

        # Run SAMSEG for lesion and tissue segmentation
        echo "Starting SAMSEG for segmentation"
        OUT_DIR=${IM_DIR}/samseg
        mkdir -p ${OUT_DIR}

        if [[ $nT1 -gt 0 ]]; 
        then
            run_samseg --input ${T1_IM} ${FLAIR_IM} --output ${OUT_DIR} \
            --pallidum-separate --lesion --lesion-mask-pattern 0 1 \
            --random-seed 22 --threads 8       
        else
            run_samseg --input ${FLAIR_IM} --output ${OUT_DIR} \
            --pallidum-separate --lesion --lesion-mask-pattern 1 \
            --random-seed 22 --threads 8
        fi
        rm ${OUT_DIR}/mode*_bias_*.mgz ${OUT_DIR}/template_coregistered.mgz
        echo "Samseg segmentation done" 

    else

        echo "Samseg segmentation already exists"
        echo ""

    fi 
    # Check Unknowns in SAMSEG result
    mrcalc ${IM_DIR}/samseg/seg.mgz 0 -eq ${HRFLMASK} -mult ${IM_DIR}/samseg/unknownswithinbrain.nii.gz -datatype bit -force -quiet
    mrstats ${IM_DIR}/samseg/unknownswithinbrain.nii.gz -mask ${IM_DIR}/samseg/unknownswithinbrain.nii.gz -quiet -output count > ${IM_DIR}/samseg/count_unknownswithinbrain.txt

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

done < ${SESS_LIST}


        