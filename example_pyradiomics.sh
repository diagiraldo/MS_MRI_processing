#!/usr/bin/zsh

# Example Pyradiomics
# Diana Giraldo, Sept 2023
# Last update: Sept 2023

# Directory with all processed MRI
PRO_DIR=/home/vlab/MS_proj/processed_MRI

# Directory for PyRadiomics test
PYRAD_DIR=/home/vlab/MS_proj/test_pyradiomics

# Example case
CASE=0253933
DATE=20150911

# Flair image
IMG_EX=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HR_FLAIR_mbSRRpy.nii.gz
cp ${IMG_EX} ${PYRAD_DIR}/flair_image.nii.gz

# LST Probabilistic lesion segmentation
LST_SEG=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LST/ples_lpa.nii.gz

# threshold LST segmentation
thLST=0.1
mrthreshold ${LST_SEG} -abs ${thLST} ${PYRAD_DIR}/lesion_mask.nii.gz

# Run Pyradiomics
pyradiomics ${PYRAD_DIR}/flair_image.nii.gz ${PYRAD_DIR}/lesion_mask.nii.gz \
-p ${PYRAD_DIR}/pyrad_settings.yaml \
-o ${PYRAD_DIR}/results.csv -f csv
