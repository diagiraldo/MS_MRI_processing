#!/usr/bin/zsh

# Interpolation of multi-slice (orthogonal) low resolution images
# with iterative rigid motion correction
# Diana Giraldo, Sept 2022
# It uses: 'mrtransform', 'mrregister', 'for_each', and 'maskfilter' from mrtrix3, 'hd-bet' 

############################################
# Inputs: 
# Folder with LR images, preprocessed with matched histograms
IN_LR_DIR=${1}
# Folder with masks
IN_MSK_DIR=${2}
# Image with template grid
GRID_TEMP=${3}
# Interpolation type
OP_INTERP=${4}
# Number of iterations for rigid motion correction
N_IT=${5}

# Output (interpolated image) name
OUT_IM_NAME=${6}
############################################

# Make temporary directory
TMP_DIR=$(mktemp -d)

# Config mrtrix
if [[ -e ~/.mrtrix.conf ]]; then
    mv ~/.mrtrix.conf ${TMP_DIR}/.prevmrtrix.conf
fi
echo 'RealignTransform: 0' >> ~/.mrtrix.conf

###########################################
# Copy LR images, 
# extract FOV and
# calculate brain masks
###########################################

nLR=$( ls ${IN_LR_DIR}/* | wc -l )
echo "-----------------------------------------"
echo "Number of input images: ${nLR}"

GRID_NAME=${GRID_TEMP##*/}
cp ${GRID_TEMP} ${TMP_DIR}/${GRID_NAME}
echo "Target size: $(mrinfo ${TMP_DIR}/${GRID_NAME} -size)"
echo "Target spacing (mm): $(mrinfo ${TMP_DIR}/${GRID_NAME} -spacing)"
echo "-----------------------------------------"

LR_DIR=${TMP_DIR}/inLR
FOV_DIR=${TMP_DIR}/fovLR
LRMASK_DIR=${TMP_DIR}/maskLR
mkdir -p ${LR_DIR} ${FOV_DIR} ${LRMASK_DIR}

# Copy images to temporary directories and calculate fields of view
for LRIM in $(ls ${IN_LR_DIR}/*.nii*);
do
    BASENAME=${${LRIM##*/}%_preproc.nii.gz}
    cp ${LRIM} ${LR_DIR}/${BASENAME}.nii.gz
    cp ${IN_MSK_DIR}/${BASENAME}_brainmask.nii.gz ${LRMASK_DIR}/${BASENAME}.nii.gz
    mrcalc ${LRIM} -isnan -not ${FOV_DIR}/${BASENAME}.nii.gz -quiet
done 

#############################
# Iterations
#############################
RG_DIR=${TMP_DIR}/regrid_LR
RGFOV_DIR=${TMP_DIR}/regrid_fovLR
mkdir -p ${RG_DIR} ${RGFOV_DIR}

iter=0

while [[ ${iter} -lt ${N_IT} ]]; do
    ((iter++))
    echo "- ITERATION ${iter}:"
    # Reference image for registration: Transversal image for first iteration
    # result of previous iteration (if N_IT > 1)
    # Init rigid registration (if iter > 1)
    if [[ ${iter} -gt 1 ]]
    then
        REG_REF=${TMP_DIR}/${INTER_NAME}
        RIG_INIT="-rigid_init_matrix ${TMP_DIR}/rigid_it$((${iter}-1))/PRE.txt"
        GRID_REF=${REG_REF}
    else
        REG_REF=$( ls ${LR_DIR}/*TRA*.nii* | head -n 1 )
        RIG_INIT=""
        GRID_REF=${TMP_DIR}/${GRID_NAME}
    fi
    # Mask of reference image
    hd-bet -i ${REG_REF} -o ${TMP_DIR}/bet_interp.nii.gz -device cpu -mode fast -tta 0 > /dev/null
    REG_REF_MASK=${TMP_DIR}/bet_interp_mask.nii.gz
    # Perform rigid registration
    echo "---- Rigid registration ..."
    RIG_TRANS=${TMP_DIR}/rigid_it${iter}
    mkdir -p ${RIG_TRANS}
    for_each -quiet ${LR_DIR}/* : mrregister IN ${REG_REF} -type rigid -rigid ${RIG_TRANS}/PRE.txt -mask1 ${LRMASK_DIR}/NAME -mask2 ${REG_REF_MASK} $(echo ${RIG_INIT}) -quiet -force
    # Transform and regrid
    for_each -quiet ${LR_DIR}/* : mrtransform IN ${RG_DIR}/NAME -linear ${RIG_TRANS}/PRE.txt -template ${GRID_REF} -interp ${OP_INTERP} -force
    for_each -quiet ${FOV_DIR}/* : mrtransform IN ${RGFOV_DIR}/NAME -linear ${RIG_TRANS}/PRE.txt -template ${GRID_REF} -interp nearest -force
    # Average (weighted by FOV)
    echo "---- Calculating image average ..."
    INTER_NAME=interp_it${iter}.nii.gz
    mrcat ${RG_DIR}/* - -quiet | mrmath - sum ${TMP_DIR}/sum_it${iter}.nii.gz -axis 3 -quiet -force
    mrcat ${RGFOV_DIR}/* - -quiet | mrmath - sum ${TMP_DIR}/fovsum_it${iter}.nii.gz -axis 3 -quiet -force
    mrcalc ${TMP_DIR}/sum_it${iter}.nii.gz ${TMP_DIR}/fovsum_it${iter}.nii.gz -div ${TMP_DIR}/${INTER_NAME} -quiet -force
    mrcalc ${TMP_DIR}/${INTER_NAME} -finite ${TMP_DIR}/${INTER_NAME} 0 -if ${TMP_DIR}/${INTER_NAME} -quiet -force
done

#############################
# Move result and remove temorary dir
#############################
mrconvert ${TMP_DIR}/${INTER_NAME} ${OUT_IM_NAME} -force -quiet
echo "- Output in ${OUT_IM_NAME}"

# restore mrtrix configuration file
rm ~/.mrtrix.conf 
if [[ -e ${TMP_DIR}/.prevmrtrix.conf ]]; then
    mv ${TMP_DIR}/.prevmrtrix.conf ~/.mrtrix.conf 
fi

rm -r ${TMP_DIR}
