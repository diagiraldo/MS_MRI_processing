#!/usr/bin/zsh

# Intensity normalization across multiple images
# Diana Giraldo, July 2022
# It uses: 'mrhistmatch', 'for_each', and 'maskfilter' from mrtrix3, 'bet' from FSL 

############################################
# Inputs: 
# Folder with preprocessed images 
IN_DIR=${1}
# Output folder to save intensity normalized images
OUT_DIR=${2}
############################################


# Make temporary directory
TMP_DIR=$(mktemp -d)

nLR=$( ls ${IN_DIR}/* | wc -l )
echo "-------------------------------------------------------------"
echo "Number of input images: ${nLR}"
echo "-------------------------------------------------------------"

IMG_DIR=${TMP_DIR}/img
MASK_DIR=${TMP_DIR}/mask
HMATCH_DIR=${TMP_DIR}/hmatch
mkdir -p ${IMG_DIR} ${MASK_DIR} ${HMATCH_DIR}

# Copy image to temporary directory
cp ${IN_DIR}/*.nii*  ${IMG_DIR}/.

# Calculate brain masks
echo "Calculating brain masks (FSL-bet) ..."
for_each -quiet ${IMG_DIR}/* : bet IN ${MASK_DIR}/NAME -n -m
for_each -quiet ${IMG_DIR}/* : maskfilter ${MASK_DIR}/PRE_mask.nii.gz clean ${MASK_DIR}/NAME -quiet

# Select transversal/axial as reference 
IM_REF=$(ls ${IMG_DIR}/sub-*_ses-*_*TRA_*.nii* | head -n 1 )
FILENAME=${IM_REF##*/}
MASK_REF=${MASK_DIR}/${FILENAME}

# Move reference image to folder of matched images
mv ${IM_REF} ${HMATCH_DIR}/.
IM_REF=${HMATCH_DIR}/${FILENAME}

# Histogram matching
echo "Scaling histograms ..."
for IM in $( ls ${IMG_DIR}/*.nii* ); 
do
 FILENAME=${IM##*/}
 MASK=${MASK_DIR}/${FILENAME}
 mrhistmatch scale ${IM} ${IM_REF} ${HMATCH_DIR}/${FILENAME} -mask_input ${MASK} -mask_target ${MASK_REF} -force -quiet
done

# Move results
echo "-------------------------------------------------------------"
mkdir -p ${OUT_DIR}
mv ${HMATCH_DIR}/* ${OUT_DIR}/. -f
echo "Output in ${OUT_DIR} "
echo "-------------------------------------------------------------"
rm -r ${TMP_DIR}
