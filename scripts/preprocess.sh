#!/usr/bin/zsh

# Preprocess nifti images: denoise, N4, brain extraction 
# Results are saver in folder of processed data
# Diana Giraldo, Nov 2022
# It requires: ANTs, anatomical template and mask 

############################################
# Inputs: 
# Raw Nifti image
RAW_IM=${1}
# Folder for processed MRI
PRO_DIR=${2}
# ANTs directory (bin)
ANTS_DIR=${3}
############################################

export ANTSPATH=${ANTS_DIR}

# Image basename
IM_BN=$(basename ${RAW_IM} | sed 's/.nii.gz//')

# Output directory
TMP_PTH=$(dirname ${RAW_IM} | rev | cut -d"/" --fields=1,2,3 | rev )
OUT_DIR=${PRO_DIR}/${TMP_PTH}
mkdir -p ${OUT_DIR}

# Denoise
DenoiseImage -d 3 -n Rician -i ${RAW_IM} -o ${OUT_DIR}/${IM_BN}_dn.nii.gz

# # Brain Extraction (for anatomical images) to improve biasfield correction
# if $(echo ${IM_BN} | grep -q -E "FLAIR"); then
#     TCLASS="3x1x3x2"
# fi
# if $(echo ${IM_BN} | grep -q -E "T1"); then
#     TCLASS="3x1x2x3"
# fi
# antsBrainExtraction.sh -d 3 -a ${OUT_DIR}/${IM_BN}_dn.nii.gz -c ${TCLASS} -e ${ANATTEMP} -m ${ANATMASK} -o ${OUT_DIR}/${IM_BN}_ > /dev/null
# mv ${OUT_DIR}/${IM_BN}_BrainExtractionMask.nii.gz ${OUT_DIR}/${IM_BN}_mask.nii.gz
# rm ${OUT_DIR}/${IM_BN}_BrainExtraction*
# N4BiasFieldCorrection -d 3 -i ${OUT_DIR}/${IM_BN}_dn.nii.gz -o ${OUT_DIR}/${IM_BN}_preproc.nii.gz -x ${OUT_DIR}/${IM_BN}_mask.nii.gz

# Biasfield correction N4
N4BiasFieldCorrection -d 3 -i ${OUT_DIR}/${IM_BN}_dn.nii.gz -o \[${OUT_DIR}/${IM_BN}_preproc.nii.gz,${OUT_DIR}/${IM_BN}_biasField.nii.gz\]

# Remove denoised image
rm ${OUT_DIR}/${IM_BN}_dn.nii.gz

############################################
# Output:
# preprocessed image 
echo ${OUT_DIR}/${IM_BN}_preproc.nii.gz
############################################