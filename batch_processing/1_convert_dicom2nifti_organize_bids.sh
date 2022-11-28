#!/usr/bin/zsh

# Read T2-FLAIR and structural T1 in DICOM, convert to nifti
# and organize them in a folder following BIDS
# Diana Giraldo, Nov 2022
# It calls convert_organize.sh and dcminfo2json.R for each image

# Scripts dir
SCR_DIR=/home/vlab/MS_MRI_processing

# DICOM dir
DCM_DIR=/home/vlab/MS_proj/DCM_imgs
# MRI dir to organize raw images
MRI_DIR=/home/vlab/MS_proj/MS_MRI

# Loop over cases/subject
for CASE in $(ls ${DCM_DIR});
do
    echo "------------------------------------------------"
    echo "CASE: ${CASE}"
    # Loop over folders per case
    for FOLDER in $(ls ${DCM_DIR}/${CASE});
    do
        echo "  folder: ${FOLDER}"
        # Loop over sT1 and Flair DICOM folders
        for  IN_DCM in $(ls -d ${DCM_DIR}/${CASE}/${FOLDER}/*(sT1|[Ff][Ll][Aa][Ii][Rr])*/); 
        do
            echo "      image: ${IN_DCM}"
            RAW_IM=$(zsh ${SCR_DIR}/scripts/convert_organize.sh ${IN_DCM} ${MRI_DIR})
            BN=${RAW_IM%.nii.gz}
            Rscript ${SCR_DIR}/scripts/dcminfo2json.R ${BN}.txt ${SCR_DIR}/data/dicomtags.csv ${BN}.json
        done
    done 
done
