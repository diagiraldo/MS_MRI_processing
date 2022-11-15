#!/usr/bin/zsh

# convert from DICOM to nifti 
# Save in folder following BIDS
# Diana Giraldo, Nov 2022
# It requires: 'dcminfo' from mrtrix3, 'dcm2niix' from MRIcroGL

############################################
# Inputs: 
# DICOM folder
IN_DCM=${1}
# Main folder for raw MRI
MRI_DIR=${2}
############################################

# Subject ID based on known folder structure
SUB_ID=$(basename $(dirname $(dirname ${IN_DCM})))
# Select first DICOM in folder to extract acquisition info
EX1_DCM=$(ls ${IN_DCM} | head -n 1)
# Extract image date from DICOM: yearmonthday
IM_DATE=$(dcminfo ${IN_DCM}/${EX1_DCM} -tag 0008 0012 | head -n 1 | awk '{print $2}' | sed 's/\///g')
# Extract Series Description and define (data)image type 
IM_DESCR=$(dcminfo ${IN_DCM}/${EX1_DCM} -tag 0008 103E | head -n 1 | sed 's/[^ ]* //' | sed 's/ //g')
if $(echo ${IM_DESCR} | grep -q -E "T2|T1|FLAIR"); then
    IM_TYPE=anat
fi
if $(echo ${IM_DESCR} | grep -q -E "DWI"); then
    IM_TYPE=dwi
fi

# Output folder - BIDS
OUT_DIR=${MRI_DIR}/sub-${SUB_ID}/ses-${IM_DATE}/${IM_TYPE}
mkdir -p ${OUT_DIR}

# File suffix: Series description + acquisition type (2D|3D) + Slice orientation
ACQ_TYPE=$(dcminfo ${IN_DCM}/${EX1_DCM} -tag 0018 0023 | head -n 1 | awk '{print $2}' )
ACQ_ORI=$(dcminfo ${IN_DCM}/${EX1_DCM} -tag 2001 100B | head -n 1 | awk '{print $2}' | cut -c1-3 )
IM_SUFF=${IM_DESCR}${ACQ_TYPE}${ACQ_ORI}

# Output name
OUT_NAME=sub-${SUB_ID}_ses-${IM_DATE}_${IM_SUFF}
OUT_IM=${OUT_DIR}/${OUT_NAME}.nii.gz

# Check if image already exists -> add rep1 to suffix
if [[ -f ${OUT_IM} ]]; then
    IM_SUFF=${IMSUFF}rep1
    OUT_NAME=sub-${SUB_ID}_ses-${IM_DATE}_${IM_SUFF}
    OUT_IM=${OUT_DIR}/${OUT_NAME}.nii.gz
fi

${D2N_DIR}/dcm2niix -z y -v 0 -o ${OUT_DIR} -f ${OUT_NAME} ${IN_DCM}

############################################
# Output:
# Nifti image location 
echo ${OUT_IM}
############################################