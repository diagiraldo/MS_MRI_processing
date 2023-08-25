#!/usr/bin/zsh

# model-based SRR multi-slice (orthogonal) low resolution images
# Diana Giraldo, Nov 2022
# Last update: August 2023

# It calls Python implementation for model-based SRR with joint motion estimation

############################################
# Inputs: 
# HR grid template, it can be the interpolation result to initialize reconstruction
HR_GRID_INIT=${1}
# Folder with LR images, adjusted for model-based SRR in python
IN_LR_DIR=${2}
# Folder with masks or FOV for LR images, adjusted for model-based SRR in python
IN_MSK_DIR=${3}

# Regularization parameter lambda
LAMBDA=${4} 
# Directory with STORM for model-based SRR
STORM_DIR=${5}

# Output (reconstructed image) name
OUT_IM_NAME=${6}
############################################

# Make temporary directory
TMP_DIR=$(mktemp -d)

# Print info
nLR=$( ls ${IN_LR_DIR}/* | wc -l )
echo "-----------------------------------------"
echo "Number of input LR images: ${nLR}"
echo "Target size: $(mrinfo ${HR_GRID_INIT} -size)"
echo "Target spacing (mm): $(mrinfo ${HR_GRID_INIT} -spacing)"
echo ""

LR_DIR=${TMP_DIR}/imgs
MSK_DIR=${TMP_DIR}/masks
mkdir -p ${LR_DIR} ${MSK_DIR}

# Copy images and associated .json to temporary directory
cp ${HR_GRID_INIT} ${TMP_DIR}/HR.nii.gz
for IM in $( ls ${IN_LR_DIR}/* ); 
do
    BASENAME=${${IM##*/}%_preproc.nii.gz}
    ORI=$(echo ${BASENAME} | grep -o "TRA\|SAG\|COR")
    JSON=$(dirname ${IN_LR_DIR})/${BASENAME}.json
    cp ${IM} ${LR_DIR}/LR_${ORI}.nii.gz 
    cp ${JSON} ${TMP_DIR}/LR_${ORI}.json
done

for MASK in $( ls ${IN_MSK_DIR}/* );
do
    ORI=$(echo $(basename ${MASK}) | grep -o "TRA\|SAG\|COR")
    cp ${MASK} ${MSK_DIR}/LR_${ORI}.nii.gz
done

# Get info about slice profile (with Transversal image)
ex_JSON=${TMP_DIR}/LR_TRA.json
SLCSPA=$( cat ${ex_JSON} | grep -Po '"Spacing​Between​Slices":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
SLCTHCK=$( cat ${ex_JSON} | grep -Po '"Slice​Thickness":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
echo "Slice spacing: ${SLCSPA}"
echo "Slice thickness: ${SLCTHCK}"
echo ""

# Call orthogonal_srr in STORM
N_ITER=20
# Ordered list of LR images
${STORM_DIR}/storm/dependencies/orthogonal_srr.py --HRref-fpath ${TMP_DIR}/HR.nii.gz --init-HRref \
--LR-fpaths ${LR_DIR}/LR_TRA.nii.gz $(ls ${LR_DIR}/LR_(SAG|COR).nii.gz) \
--LRmasks-fpaths ${MSK_DIR}/LR_TRA.nii.gz $(ls ${MSK_DIR}/LR_(SAG|COR).nii.gz) \
--slice-spacing ${SLCSPA} --reg-weight ${LAMBDA} --n-iterations ${N_ITER} \
--out-dir ${TMP_DIR} --print-info --save-optim-history
#--slice-thickness ${SLCTHCK} \ 

# Move to output directory
cp ${TMP_DIR}/recon.nii.gz ${OUT_IM_NAME}
echo "Output saved in ${OUT_IM_NAME}"
prefx=$(dirname ${OUT_IM_NAME})/${$(basename ${OUT_IM_NAME})%.nii*}
cp ${TMP_DIR}/rotation.npy ${prefx}_rotation.npy 
cp ${TMP_DIR}/translation.npy ${prefx}_translation.npy 
cp ${TMP_DIR}/optim_history.csv ${prefx}_optim_history.csv

rm -r ${TMP_DIR}
