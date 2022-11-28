#!/usr/bin/zsh

# convert from DICOM to nifti 
# Save in folder following BIDS
# Diana Giraldo, Nov 2022
# It requires: 'dcminfo' and 'mrconvert' from mrtrix3

############################################
# Inputs: 
# DICOM folder
IN_DCM=${1}
# Main folder for raw MRI
MRI_DIR=${2}
############################################

# Config mrtrix
mv ~/.mrtrix.conf ~/.prevmrtrix.conf
echo 'RealignTransform: 0' >> ~/.mrtrix.conf

# Subject ID based on known folder structure
SUB_ID=$(basename $(dirname $(dirname ${IN_DCM})))
# Select first DICOM in folder to extract acquisition info
EX1_DCM=$(ls ${IN_DCM} | head -n 1)
# Extract image date from DICOM: yearmonthday
IM_DATE=$(dcminfo ${IN_DCM}/${EX1_DCM} -tag 0008 0012 | head -n 1 | awk '{print $2}' | sed 's/\///g')
# Extract Series Description and define (data)image type 
IM_DESCR=$(dcminfo ${IN_DCM}/${EX1_DCM} -tag 0008 103E | head -n 1 | sed 's/[^ ]* //' | sed 's/ //g')
if $(echo ${IM_DESCR} | grep -q -E "T2|T1|[Ff][Ll][Aa][Ii][Rr]"); then
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
repidx=1
while [[ -f ${OUT_IM} ]]; 
do
    OUT_NAME=sub-${SUB_ID}_ses-${IM_DATE}_${IM_SUFF}_rep${repidx}
    OUT_IM=${OUT_DIR}/${OUT_NAME}.nii.gz
    repidx=$(( $repidx + 1 ))
done

# Convert from DICOM to nifti
mrconvert ${IN_DCM} ${OUT_DIR}/${OUT_NAME}.nii.gz
# Export info from DICOM to .txt (to .json?)
dcminfo ${IN_DCM}/${EX1_DCM} -tag 0008 0012 -tag 0008 0060 -tag 0018 0087 -tag 0018 0084 -tag 0008 0070 -tag 0008 1090 -tag 0008 1010 -tag 0018 0015 -tag 0018 5100 -tag 0018 1020 -tag 0018 0023 -tag 0008 103E -tag 0018 1030 -tag 0018 0020 -tag 0018 0021 -tag 0018 0022 -tag 0008 0032 -tag 0020 0011 -tag 0020 0012 -tag 0018 0050 -tag 0018 0088 -tag 0018 1316 -tag 0018 0080 -tag 0018 0081 -tag 0018 0082 -tag 0018 1314 -tag 0018 1250 -tag 0018 1251 -tag 0018 0089 -tag 0018 0091 -tag 0018 0093 -tag 0018 0094 -tag 0018 0095 -tag 0018 1310 -tag 0018 1312 -tag 0028 0030 -tag 0028 0010 -tag 0028 0011 -tag 2001 100B -tag 0020 0037 > ${OUT_DIR}/${OUT_NAME}.txt

mv ~/.prevmrtrix.conf ~/.mrtrix.conf

############################################
# Output:
# Nifti image location 
echo ${OUT_IM}
############################################
