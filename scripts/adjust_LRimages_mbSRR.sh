#!/usr/bin/zsh

# Adjust LR images to perform model-based SRR based on a HR grid
# Diana Giraldo, August 2022
# It uses commands from mrtrix3 

############################################
# Inputs: 
# Folder with intensity normalised LR images
IN_LR_DIR=${1}
# HR grid
IN_HR_GRID=${2}
# Folder with reorientation script
SCR_DIR=${3}

# Outputs:
# Folder with adjusted LR images
OUT_LR_DIR=${4}
############################################

# Make temporary directory
TMP_DIR=$(mktemp -d)

# Config mrtrix
if [[ -e ~/.mrtrix.conf ]]; then
    mv ~/.mrtrix.conf ${TMP_DIR}/.prevmrtrix.conf
fi
echo 'RealignTransform: 0' >> ~/.mrtrix.conf

IMG_DIR=${TMP_DIR}/img
mkdir -p ${IMG_DIR} 

# Copy (convert to nifti) images to temporary directory
mrconvert ${IN_HR_GRID} ${TMP_DIR}/HRgrid.nii
for IM in $( ls ${IN_LR_DIR}/* ); 
do
 ORI=$(echo $(basename ${IM}) | grep -o "TRA\|SAG\|COR")
 mrconvert ${IM} ${IMG_DIR}/LR_${ORI}.nii -quiet -force
done

# Get slice spacing from transversal image
SF=$( mrinfo ${IMG_DIR}/LR_TRA.nii -spacing | cut -d" " -f3 )

# Get isotropic voxel size from HR grid
ISOVOX=$( mrinfo ${TMP_DIR}/HRgrid.nii -spacing | cut -d" " -f1 )

# Regrid LR images to ${ISOVOX},${ISOVOX},${SF}
for IM in $( ls ${IMG_DIR}/* ); 
do
    ORI=$(echo $(basename ${IM}) | grep -o "TRA\|SAG\|COR")
    mrgrid ${IM} regrid -vox ${ISOVOX},${ISOVOX},${SF} - -quiet | mrcalc - -abs ${TMP_DIR}/LR_${ORI}_1.nii -force -quiet
done

# To know how to crop and pad LR images, HRgrid needs to be modified: regrid to anisotropic voxels to get FOV in LR and reoriented
mrgrid ${TMP_DIR}/HRgrid.nii regrid -vox ${ISOVOX},${ISOVOX},${SF} -interp nearest ${TMP_DIR}/fov_TRA.nii -force -quiet
mrgrid ${TMP_DIR}/HRgrid.nii regrid -vox ${SF},${ISOVOX},${ISOVOX} -interp nearest ${TMP_DIR}/fov_SAG.nii -force -quiet
mrgrid ${TMP_DIR}/HRgrid.nii regrid -vox ${ISOVOX},${SF},${ISOVOX} -interp nearest ${TMP_DIR}/fov_COR.nii -force -quiet

for IM in $( ls ${TMP_DIR}/LR_*_1.nii ); 
do
    ORI=$(echo $(basename ${IM}) | grep -o "TRA\|SAG\|COR")
    ${SCR_DIR}/reorient_nifti.py --input ${TMP_DIR}/fov_${ORI}.nii --reference ${IM} --output ${TMP_DIR}/fov_aligned_${ORI}.nii 
done

# Pad LR images (if necessary)
extravox=1
for IM in $( ls ${TMP_DIR}/LR_*_1.nii ); 
do
    ORI=$(echo $(basename ${IM}) | grep -o "TRA\|SAG\|COR")
    targetdim=$(mrinfo ${TMP_DIR}/fov_aligned_${ORI}.nii -size)
    imdim=$(mrinfo ${IM} -size)
    xdiff=$(( $(echo ${targetdim} | cut -d' ' -f1)-$(echo ${imdim} | cut -d' ' -f1) ))
    xp1=$(( ${xdiff} > 0 ? ${xdiff} : ${extravox} ))
    ydiff=$(( $(echo ${targetdim} | cut -d' ' -f2)-$(echo ${imdim} | cut -d' ' -f2) ))
    yp1=$(( ${ydiff} > 0 ? ${ydiff} : ${extravox} ))
    zdiff=$(( $(echo ${targetdim} | cut -d' ' -f3)-$(echo ${imdim} | cut -d' ' -f3) ))
    zp1=$(( ${zdiff} > 0 ? ${zdiff} : ${extravox} ))
    mrgrid ${IM} pad ${TMP_DIR}/LR_${ORI}_2.nii -axis 0 ${xp1},${xp1} -axis 1 ${yp1},${yp1} -axis 2 ${zp1},${zp1} -force -quiet
done

# Crop LR images
for FOV in $( ls ${TMP_DIR}/fov_aligned_*.nii );
do
    ORI=$(echo $(basename ${FOV}) | grep -o "TRA\|SAG\|COR")
    # Embed FOV in LR image grid (the interpolation can change the needed fov)
    mrcalc ${FOV} -finite - -quiet | mrgrid - regrid -template ${TMP_DIR}/LR_${ORI}_2.nii -interp nearest ${TMP_DIR}/fov_aligned_${ORI}_mask.nii -force -quiet
    # crop LR images according to FOV
    mrgrid ${TMP_DIR}/LR_${ORI}_2.nii crop ${TMP_DIR}/LR_${ORI}_3.nii -mask ${TMP_DIR}/fov_aligned_${ORI}_mask.nii -uniform 0 -force -quiet
    # Last check, crop potential extra voxels
    targetdim=$(mrinfo ${FOV} -size)
    imdim=$(mrinfo ${TMP_DIR}/LR_${ORI}_3.nii -size)
    xdiff=$(( $(echo ${imdim} | cut -d' ' -f1)-$(echo ${targetdim} | cut -d' ' -f1) ))
    ydiff=$(( $(echo ${imdim} | cut -d' ' -f2)-$(echo ${targetdim} | cut -d' ' -f2) ))
    zdiff=$(( $(echo ${imdim} | cut -d' ' -f3)-$(echo ${targetdim} | cut -d' ' -f3) ))
    xp1=$(( ${xdiff}/2 ))
    xp2=$(( ${xdiff} - ${xp1} )) 
    yp1=$(( ${ydiff}/2 ))
    yp2=$(( ${ydiff} - ${yp1} ))
    zp1=$(( ${zdiff}/2 ))
    zp2=$(( ${zdiff} - ${zp1} ))
    mrgrid ${TMP_DIR}/LR_${ORI}_3.nii crop ${TMP_DIR}/LR_${ORI}_adjusted.nii.gz -axis 0 ${xp1},${xp2} -axis 1 ${yp1},${yp2} -axis 2 ${zp1},${zp2} -force -quiet
done

# Copy adjusted images to output folder
mkdir -p ${OUT_LR_DIR}
for IM in $( ls ${IN_LR_DIR}/* ); 
do
    ORI=$(echo $(basename ${IM}) | grep -o "TRA\|SAG\|COR")
    filename="${$(basename ${IM})%%.*}"
    cp ${TMP_DIR}/LR_${ORI}_adjusted.nii.gz ${OUT_LR_DIR}/${filename}.nii.gz
done

# restore mrtrix configuration file
rm ~/.mrtrix.conf 
if [[ -e ${TMP_DIR}/.prevmrtrix.conf ]]; then
    mv ${TMP_DIR}/.prevmrtrix.conf ~/.mrtrix.conf 
fi

rm -r ${TMP_DIR}
