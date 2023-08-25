#!/usr/bin/zsh

# model-based SRR multi-slice (orthogonal) low resolution images
# Diana Giraldo, Nov 2022
# Last update: August 2023

# It calls MATLAB implementation for model-based SRR with joint motion estimation
# It uses: 'mrconvert', 'mrcalc', 'for_each', from mrtrix3, and 'hd-bet' for brain mask

############################################
# Inputs: 
# Folder with LR images, preprocessed with matched histograms
IN_LR_DIR=${1}
# Folder with masks
IN_MSK_DIR=${2}
# Ititial interpolation to initialize reconstruction (also the template grid) 
HR_GRID_INIT=${3}
# Regularization parameter lambda
LAMBDA=${4} 
# Directory with MATLAB functions for model-based SRR
mSRR_DIR=${5}
# Directory with MATLAB Building Blocks for model-based SRR
BB_DIR=${6}

# Output (reconstructed image) name
OUT_IM_NAME=${7}
############################################

# Make temporary directory
TMP_DIR=$(mktemp -d)

# Config mrtrix
if [[ -e ~/.mrtrix.conf ]]; then
    mv ~/.mrtrix.conf ${TMP_DIR}/.prevmrtrix.conf
fi
echo 'RealignTransform: 0' >> ~/.mrtrix.conf

# Print info
nLR=$( ls ${IN_LR_DIR}/* | wc -l )
echo "-----------------------------------------"
echo "Number of input images: ${nLR}"
echo "Target size: $(mrinfo ${HR_GRID_INIT} -size)"
echo "Target spacing (mm): $(mrinfo ${HR_GRID_INIT} -spacing)"
echo "-----------------------------------------"

# Convert input images (and masks) to .mif
mifs_DIR=${TMP_DIR}/LR_mifs
masks_DIR=${TMP_DIR}/LR_masks
mkdir -p ${mifs_DIR} ${masks_DIR}

for LRIM in $(ls ${IN_LR_DIR}/*);
do
    BASENAME=${${LRIM##*/}%_preproc.*}
    ORI=$(echo ${BASENAME} | grep -o "TRA\|SAG\|COR")
    mrconvert ${LRIM} ${mifs_DIR}/LR_${ORI}.mif -quiet -force
done

for MASK in $(ls ${IN_MSK_DIR}/*);
do
    BASENAME=${${MASK##*/}%_brainmask.*}
    ORI=$(echo ${BASENAME} | grep -o "TRA\|SAG\|COR")
    mrconvert ${MASK} ${masks_DIR}/LR_${ORI}.mif -quiet -force
done


INIT_NAME=${${HR_GRID_INIT##*/}%.nii*}
HR_INIT=${TMP_DIR}/${INIT_NAME}.mif
mrconvert ${HR_GRID_INIT} ${HR_INIT} -quiet -force
hd-bet -i ${HR_GRID_INIT} -o ${TMP_DIR}/bet_init.nii.gz -device cpu -mode fast -tta 0 > /dev/null
mrconvert ${TMP_DIR}/bet_init_mask.nii.gz ${TMP_DIR}/bet_init_mask.mif -quiet -force

# Read DICOM info about slice profile
ex_LR=$(ls ${IN_LR_DIR}/* | head -n 1 )
ex_LR_NAME=${${ex_LR##*/}%_preproc.*}
ex_JSON=$(dirname ${IN_LR_DIR})/${ex_LR_NAME}.json
ACQ_TYPE=$( cat ${ex_JSON} | grep -Po '"MR​Acquisition​Type":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
if [[ ${ACQ_TYPE} == 3D ]] 
then
    SLW=0
else
    SLCTH=$( cat ${ex_JSON} | grep -Po '"Slice​Thickness":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
    SLCSPA=$( cat ${ex_JSON} | grep -Po '"Spacing​Between​Slices":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
    SLW=$( awk "BEGIN {print ${SLCTH}/${SLCSPA}}" )
    # Scale LR according to SLW
    for_each ${mifs_DIR}/*.mif : mrcalc IN ${SLW} -mult IN -quiet -force
fi

# Call MATLAB function

HR_MASK=${TMP_DIR}/bet_init_mask.mif
TMP_OUT=${TMP_DIR}/output_withmasks.mif
matlab -nodisplay -r "cd('$mSRR_DIR'); SRR_QuintenB_motion_v2_withmasks('$BB_DIR', '$mifs_DIR', '$masks_DIR', '$TMP_OUT', '$HR_INIT', '$HR_MASK', '$SLW', '$LAMBDA'); exit"

# Convert output
mrconvert ${TMP_OUT} ${OUT_IM_NAME} -force -quiet
echo "- Output in ${OUT_IM_NAME}"

# restore mrtrix configuration file
rm ~/.mrtrix.conf 
if [[ -e ${TMP_DIR}/.prevmrtrix.conf ]]; then
    mv ${TMP_DIR}/.prevmrtrix.conf ~/.mrtrix.conf 
fi

rm -r ${TMP_DIR}