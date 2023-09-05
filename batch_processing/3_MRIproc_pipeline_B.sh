#!/usr/bin/zsh

# Process sessions with LR FLAIR acquired with protocol (B)
# Diana Giraldo, Dec 2022
# Last update: August 2023

# ANTs directory
ANTS_DIR=/opt/ANTs/bin
# Processing repo directory
SCR_DIR=/home/vlab/MS_MRI_processing/scripts

# STORM directory for model-based SRR in python
STORM_DIR=/home/vlab/STORM

# SPM and LST auxiliary functions
SPM_DIR=/home/vlab/spm12/
SEGF_DIR=${SCR_DIR}/LSTfunctions/

# Raw MRI dir
MRI_DIR=/home/vlab/MS_proj/MS_MRI
# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI

###################################################################################
# List of sessions (Subject Date) to process
PP=B
SS_LIST=/home/vlab/MS_proj/info_files/subject_date_proc_${PP}.txt

# BEFORE RUNING PIPELINE Move previous reconstructions and results
while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    echo " "

    if [[ -f  ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRR.nii.gz ]];
    then
        echo 'previous model-based SRR exists'
        mv ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRR.nii.gz ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/prev_HR_FLAIR_mbSRR.nii.gz

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

    fi

done < ${SS_LIST}

# RE-RUN of: pre-processing, and model-based SRR with Python implementation

while IFS= read -r line;
do
    CASE=$(echo $line | awk '{print $1}')
    DATE=$(echo $line | awk '{print $2}')
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    echo "Session date: ${DATE}"
    echo ""

    OUT_SRRpy=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRRpy.nii.gz

    if [[ ! -f ${OUT_SRRpy} ]]; then

        # Pre-process images
        echo "Starting pre-processing"
        for RAW_IM in $(ls ${MRI_DIR}/sub-${CASE}/ses-${DATE}/anat/*(sT1|[Ff][Ll][Aa][Ii][Rr])*.nii*);
        do
            zsh ${SCR_DIR}/preprocess.sh ${RAW_IM} ${PRO_DIR} ${ANTS_DIR}
        done
        echo "Pre-processing done"
        echo ""

        # Use available LR FLAIR to obtain a HR image

        echo "Preparing LR FLAIR images"
        slcth=2
        # Copy LR FLAIR (and masks) to subfolders
        FL_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_preproc
        BM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_masks
        rm -r ${BM_DIR}
        mkdir -p ${FL_DIR} ${BM_DIR}
        for IM in $(ls ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/*[Ff][Ll][Aa][Ii][Rr]*preproc.nii.gz); 
        do
            SLC=$( mrinfo ${IM} -spacing -config RealignTransform 0 | cut -d" " -f3 )
            if [[ ${SLC} > ${slcth} ]]; then
                cp ${IM} ${FL_DIR}/.
                cp ${IM%_preproc.nii.gz}_brainmask.nii.gz ${BM_DIR}/.
            fi
        done

        # Histogram matching
        HM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_hmatch
        rm -r ${HM_DIR}
        zsh ${SCR_DIR}/histmatch_folder.sh ${FL_DIR} ${BM_DIR} ${HM_DIR}
        rm -r ${FL_DIR}
        echo "Histogram matching done"
        echo ""

        # Grid template
        ISOVOX=1
        HR_grid=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HRgrid_${ISOVOX}mm.nii.gz
        zsh ${SCR_DIR}/get_HRgrid.sh ${BM_DIR} ${ISOVOX} ${HR_grid}
        echo "HR grid template in ${HR_grid}"
        echo ""

        # Interpolation
        N_IT=4
        OP_INTERP=cubic
        HRFL_INT=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_interp.nii.gz
        zsh ${SCR_DIR}/mSR_interpolation.sh ${HM_DIR} ${BM_DIR} ${HR_grid} ${OP_INTERP} ${N_IT} ${HRFL_INT}
        echo "Interpolated HR image in ${HRFL_INT}"
        echo ""

        # Model-based SRR with python code
        # Adjust LR images
        LRADJ_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_adjusted
        BMADJ_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_MASK_adjusted
        FOVADJ_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FOV_adjusted
        zsh ${SCR_DIR}/adjust_LRimages_mbSRR.sh ${HR_grid} ${HM_DIR} ${BM_DIR} ${LRADJ_DIR} ${BMADJ_DIR} ${FOVADJ_DIR}
        # Run python script
        LAMBDA=0.1
        zsh ${SCR_DIR}/model-based_SRR_py.sh ${HRFL_INT} ${LRADJ_DIR} ${FOVADJ_DIR} ${LAMBDA} ${STORM_DIR} ${OUT_SRRpy}
        rm -r ${LRADJ_DIR} ${BMADJ_DIR} ${FOVADJ_DIR}
        echo "Output of model-based SRR in ${OUT_SRRpy}"
        echo ""

    else

        echo "Output of model-based SRR already exists in ${OUT_SRRpy}"
        echo ""

    fi

    echo "-----------------------------------------"

done < ${SS_LIST}