#!/usr/bin/zsh

# model-based SRR multi-slice (orthogonal) low resolution images
# Diana Giraldo, Nov 2022
# It calls MATLAB implementation for model-based SRR with joint motion estimation
# It uses: 'mrtransform', 'for_each', from mrtrix3

############################################
# Inputs: 
# Folder with LR images, preprocessed with matched histograms
IN_LR_DIR=${1}
# Ititial interpolation to initialize reconstruction
# It is also the template grid
INIT_INTERP=${2}
# Regularization parameter lambda
LAMBDA=${3} 
# Directory with MATLAB functions for model-based SRR
mSRR_DIR=${4}
# Directory with Building Blocks for model-based SRR
BB_DIR=${5}

# Output (reconstructed image) name
OUT_IM_NAME=${6}
############################################

IN_LR_DIR=/home/vlab/MS_proj/processed_MRI/sub-2400402/ses-20170227/anat/LR_FLAIR_hmatch
INIT_INTERP=/home/vlab/MS_proj/processed_MRI/sub-2400402/ses-20170227/anat/HR_FLAIR_interp.nii.gz
LAMBDA=0.1
mSRR_DIR=/home/vlab/SR_MS_eval/ModelBasedSRR
BB_DIR=/home/vlab/SR_MS_eval/BuildingBlocks
OUT_IM_NAME=/home/vlab/MS_proj/processed_MRI/sub-2400402/ses-20170227/anat/HR_FLAIR_mbSRR.nii.gz

# Make temporary directory
TMP_DIR=$(mktemp -d)

# Config mrtrix
mv ~/.mrtrix.conf ${TMP_DIR}/.prevmrtrix.conf
echo 'RealignTransform: 0' >> ~/.mrtrix.conf

# Print info
nLR=$( ls ${IN_LR_DIR}/* | wc -l )
echo "-----------------------------------------"
echo "Number of input images: ${nLR}"
echo "Target size: $(mrinfo ${INIT_INTERP} -size)"
echo "Target spacing (mm): $(mrinfo ${INIT_INTERP} -spacing)"
echo "-----------------------------------------"

# Convert input images to .mif
mifs_DIR=${TMP_DIR}/LR_mifs
mkdir -p ${mifs_DIR}

INIT_NAME=${${INIT_INTERP##*/}%.nii*}
mrconvert ${INIT_INTERP} ${TMP_DIR}/${INIT_NAME}.mif

for_each -quiet ${IN_LR_DIR}/* : mrconvert IN ${mifs_DIR}/PRE.mif -force

# Read DICOM info about slice profile
ex_LR_NAME=$(ls ${mifs_DIR} | head -n 1 | sed 's/_preproc.mif//')
ex_JSON=$(dirname ${IN_LR_DIR})/${ex_LR_NAME}.json
ACQ_TYPE=$( cat ${ex_JSON} | grep -Po '"MR​Acquisition​Type":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
if [[ ${ACQ_TYPE} == 3D ]] 
then
    SLW=0
else
    SLCTH=$( cat ${ex_JSON} | grep -Po '"Slice​Thickness":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
    SLCSPA=$( cat ${ex_JSON} | grep -Po '"Spacing​Between​Slices":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
    SLW=$( awk "BEGIN {print ${SLCTH}/${SLCSPA}}" )
fi

# Call MATLAB function
TMP_OUT=${TMP_DIR}/output.mif
HR_INIT=${TMP_DIR}/${INIT_NAME}.mif
matlab -nodisplay -r "cd('$mSRR_DIR'); SRR_QuintenB_motion_v2('$BB_DIR', '$mifs_DIR', '$TMP_OUT', '$HR_INIT', '$SLW', '$LAMBDA'); exit"