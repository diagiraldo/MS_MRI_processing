#!/usr/bin/zsh

# Convert and PRE-process HR FLAIR in MRI_Zuyderland dataset
# Diana Giraldo, Nov 2023
# Last update: Nov 2023

# DICOM dir
DCM_DIR=/mnt/extradata/MRI_Zuyderland/Output_3_9_2023
# Acquisition info dir 
ACQ_DIR=/mnt/extradata/MRI_Zuyderland/acquisition_info
# Processed MRI dir
PRO_DIR=/home/vlab/MS_proj/processed_MRI_zuy

#IMG_LIST=/home/vlab/MS_proj/info_files/imgs_zuy_proc_HR_FLAIR.txt 
#IMG_LIST=/home/vlab/MS_proj/info_files/imgs_zuy_proc_LR_FLAIR.txt  
#IMG_LIST=/home/vlab/MS_proj/info_files/imgs_zuy_proc_LR_FLAIR_and_HR_T1W.txt
IMG_LIST=/home/vlab/MS_proj/info_files/imgs_zuy_proc_HR_FLAIR_and_HR_T1W.txt


while IFS= read -r line;
do
    SUB=$(echo $line | awk '{print $1}')
    SESS=$(echo $line | awk '{print $2}')
    DCMNAME=$(echo $line | awk '{print $3}')
    CTRST=$(echo $line | awk '{print $4}')

    echo "-----------------------------------------"
    echo "Subject: ${SUB}, Session: ${SESS}"
    echo "DICOM: ${DCMNAME}"

    rawIMG_DIR=$(find ${DCM_DIR}/${SUB}/${SESS} -name "${DCMNAME}" -type d)
    #mrinfo ${rawIMG_DIR}

    JSFILE=$(find ${ACQ_DIR}/${SUB}/${SESS}/${DCMNAME}*.json)
    echo $JSFILE

    # Make temporary directory
    TMP_DIR=$(mktemp -d)

    # Convert from DICOM to nifti
    mrconvert ${rawIMG_DIR} ${TMP_DIR}/raw.nii.gz -config RealignTransform 0

    # Denoise 
    echo "Denoising..."
    DenoiseImage -d 3 -n Rician -i ${TMP_DIR}/raw.nii.gz -o ${TMP_DIR}/dn.nii.gz
    # Calculate absolute value to remove negatives
    ImageMath 3 ${TMP_DIR}/dnabs.nii.gz abs ${TMP_DIR}/dn.nii.gz
    mv ${TMP_DIR}/dnabs.nii.gz ${TMP_DIR}/dn.nii.gz

    # Estimate Brain mask 
    echo "HD-BET..."
    hd-bet -i ${TMP_DIR}/dn.nii.gz -o ${TMP_DIR}/bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
    rm ${TMP_DIR}/bet.nii.gz
    mv ${TMP_DIR}/bet_mask.nii.gz ${TMP_DIR}/brainmask.nii.gz

    # Biasfield correction N4
    echo "Biasfield correction..."
    N4BiasFieldCorrection -d 3 -i ${TMP_DIR}/dn.nii.gz -o ${TMP_DIR}/dn_N4.nii.gz -x ${TMP_DIR}/brainmask.nii.gz

    # Output folder
    OUT_DIR=${PRO_DIR}/sub-${SUB}/ses-${SESS}/anat
    mkdir -p ${OUT_DIR}

    # Image name
    OUT_NAME=sub-${SUB}_ses-${SESS}_${DCMNAME}__${CTRST}

    # Move to output folder
    mv ${TMP_DIR}/dn_N4.nii.gz ${OUT_DIR}/${OUT_NAME}_preproc.nii.gz
    mv ${TMP_DIR}/brainmask.nii.gz ${OUT_DIR}/${OUT_NAME}_brainmask.nii.gz
    cp ${JSFILE} ${OUT_DIR}/${OUT_NAME}.json

    echo "Pre-processed image in ${OUT_DIR}/${OUT_NAME}_preproc.nii.gz"

    # remove tmp dir 
    rm -r ${TMP_DIR}

done < ${IMG_LIST}
