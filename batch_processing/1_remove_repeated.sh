#!/usr/bin/zsh

# Remove repeated images 
# Diana Giraldo, Nov 2022

# MRI dir to organize raw images
MRI_DIR=/home/vlab/MS_proj/MS_MRI

# Compare and rename if it should be removed 
for IMREP in $(ls ${MRI_DIR}/*/*/anat/*_rep*.nii.gz);
do
    #echo "------------------------------------------------"
    #echo ${IMREP}
    IMORI=${IMREP%_rep*.nii*}.nii.gz
    #echo ${IMORI}
    maxdiff=$(mrcalc ${IMREP} ${IMORI} -subtract -abs - -quiet | mrstats - -output max)
    #echo "Max diff: ${maxdiff}"
    if [[ ${maxdiff} -le 0 ]]; then
        mv ${IMREP} ${IMREP%_rep*.nii*}_TOREMOVE.nii.gz
    fi
done

# Remove them 
rm ${MRI_DIR}/*/*/anat/*_TOREMOVE.nii.gz

# Correct two cases 
# sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG
mv ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG.nii.gz ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG_obli.nii.gz
mv ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG.txt ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG_obli.txt
mv ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG.json ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG_obli.json

mv ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG_rep1.nii.gz ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG.nii.gz
mv ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG_rep1.txt ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG.txt
mv ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG_rep1.json ${MRI_DIR}/sub-0116928/ses-20120525/anat/sub-0116928_ses-20120525_T2WFLAIR2DSAG.json

# sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR
mv ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR.nii.gz ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR_cut.nii.gz
mv ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR.txt ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR_cut.txt
mv ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR.json ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR_cut.json

mv ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR_rep1.nii.gz ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR.nii.gz
mv ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR_rep1.txt ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR.txt
mv ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR_rep1.json ${MRI_DIR}/sub-0235127/ses-20160506/anat/sub-0235127_ses-20160506_FLAIRCor3mm3DCOR.json

# Removed extra .txt and .json
rm ${MRI_DIR}/*/*/anat/*_rep1.txt ${MRI_DIR}/*/*/anat/*_rep1.json

# Rename or remove files ls ${MRI_DIR}/*/*/anat/*.* | grep -E '\s|\*|\(' 
rm ${MRI_DIR}/sub-0132848/ses-20120330/anat/sub-0132848_ses-20120330_\(DIR\)*
rm ${MRI_DIR}/sub-2403379/ses-20110713/anat/sub-2403379_ses-20110713_STIR_FLAIR\(TESTEN\)2DTRA.*
