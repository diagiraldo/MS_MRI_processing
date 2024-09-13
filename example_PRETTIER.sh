SCR_DIR=/home/vlab/mri_toolkit

export PYTHONPATH=/home/vlab/mrtrix3/lib:$PYTHONPATH

# Apply prettier to each LR 

HR_grid=HRgrid_1mm.nii.gz


mkdir LR_FLAIR_prettier
for IM in $(ls LR_FLAIR_hmatch/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/_preproc.nii.gz//')\
    ~/PRETTIER/prettier_mri.py --LR-input ${IM} --model-name EDSR --output LR_FLAIR_prettier/${IM_BN}_prettierEDSR.nii.gz --batch-size 4\
done

mkdir LR_FLAIR_prettier_masks\
for IM in $(ls LR_FLAIR_prettier/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/.nii.gz//')\
    hd-bet -i ${IM} -o LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null\
    rm LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz\
    mv LR_FLAIR_prettier_masks/${IM_BN}_bet_mask.nii.gz LR_FLAIR_prettier_masks/${IM_BN}_brainmask.nii.gz\
done

${SCR_DIR}/align_combine_mrtrix3.py $(ls LR_FLAIR_prettier/*.nii.gz) ${HR_grid} HR_combined_prettierEDSR.nii.gz -masks $(ls LR_FLAIR_prettier_masks/*.nii.gz) -iter 1 -force

mrregister LR_FLAIR_prettier/sub-0030403_ses-20120507_T2WFLAIR2DTRA_prettierEDSR.nii.gz LR_FLAIR_prettier/sub-0030403_ses-20120507_T2WFLAIR2DSAG_prettierEDSR.nii.gz -type rigid -mask1 LR_FLAIR_prettier_masks/sub-0030403_ses-20120507_T2WFLAIR2DTRA_prettierEDSR_brainmask.nii.gz -mask2 LR_FLAIR_prettier_masks/sub-0030403_ses-20120507_T2WFLAIR2DSAG_prettierEDSR_brainmask.nii.gz -transformed LR_FLAIR_prettier/tmp_TRA2SAG.nii.gz

${SCR_DIR}/combine_aligned_images.py --inputs LR_FLAIR_prettier/sub-0030403_ses-20120507_T2WFLAIR2DSAG_prettierEDSR.nii.gz LR_FLAIR_prettier/tmp_TRA2SAG.nii.gz --output HR_combined2_prettierEDSR.nii.gz 

${SCR_DIR}/combine_aligned_images.py --inputs LR_FLAIR_prettier/sub-0030403_ses-20120507_T2WFLAIR2DSAG_prettierEDSR.nii.gz LR_FLAIR_prettier/tmp_TRA2SAG.nii.gz --output HR_combined3_prettierEDSR.nii.gz --method FBA


~/PRETTIER/prettier_mri.py --LR-input LR_FLAIR_hmatch/sub-2400402_ses-20170227_FLAIRTra3mm3DTRA_preproc.nii.gz --model-name EDSR --output LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRTra3mm3DTRA_prettierEDSR.nii.gz --batch-size 3
: 1722005630:0;mrview LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRTra3mm3DTRA_prettierEDSR.nii.gz 
: 1722005731:0;~/PRETTIER/prettier_mri.py --LR-input LR_FLAIR_hmatch/sub-2400402_ses-20170227_FLAIRCor3mm3DCOR_preproc.nii.gz --model-name EDSR --output LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRCor3mm3DCOR_prettierEDSR.nii.gz --batch-size 4
: 1722006078:0;cp mri_super-resolution/scripts/align_combine.py MS_MRI_processing/scripts/.
: 1722006152:0;~/PRETTIER/prettier_mri.py --LR-input LR_FLAIR_hmatch/sub-2400402_ses-20170227_FLAIRSag3mm3DSAG_preproc.nii.gz --model-name EDSR --output LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRSag3mm3DSAG_prettierEDSR.nii.gz --batch-size 5
: 1722006176:0;~/PRETTIER/prettier_mri.py --LR-input LR_FLAIR_hmatch/sub-2400402_ses-20170227_FLAIRSag3mm3DSAG_preproc.nii.gz --model-name EDSR --output LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRSag3mm3DSAG_prettierEDSR.nii.gz --batch-size 3
: 1722006317:0;ls MS_proj/processed_MRI/sub-2400402/ses-20170227/anat
: 1722006606:0;SCR_DIR=/home/vlab/MS_MRI_processing/scripts\
BM_DIR=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/LR_FLAIR_masks\
ISOVOX=0.5\
HR_grid=${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat/HRgrid_${ISOVOX}mm.nii.gz\
zsh ${SCR_DIR}/get_HRgrid.sh ${BM_DIR} ${ISOVOX} ${HR_grid}
: 1722006781:0;chmod +x ~/MS_MRI_processing/scripts/align_combine.py
: 1722006801:0;${SCR_DIR}/align_combine.py
: 1722006827:0;conda activate mri_sr
: 1722006833:0;conda info --envs
: 1722006845:0;conda activate esrgan
: 1722006855:0;${SCR_DIR}/align_combine.py
: 1722006940:0;conda deactivate esrgan
: 1722006959:0;export PYTHONPATH=/home/vlab/mrtrix3/lib:$PYTHONPATH
: 1722006968:0;conda deactivate esrgan
: 1722006976:0;conda deactivate 
: 1722006982:0;export PYTHONPATH=/home/vlab/mrtrix3/lib:$PYTHONPATH
: 1722006987:0;${SCR_DIR}/align_combine.py
: 1722007068:0;ls
: 1722007109:0;${SCR_DIR}/align_combine.py LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRTra3mm3DTRA_prettierEDSR.nii.gz LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRCor3mm3DCOR_prettierEDSR.nii.gz LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRSag3mm3DSAG_prettierEDSR.nii.gz ${HR_grid} HR_combined_prettierEDSR.nii.gz
: 1722007238:0;ls
: 1722007262:0;mrview HR_combined_prettierEDSR.nii.gz HR_FLAIR_mbSRRpy.nii.gz
: 1722007398:0;mrview HR_combined_prettierEDSR.nii.gz HR_FLAIR_mbSRRpy.nii.gz LR_FLAIR_prettier/*
: 1722007608:0;mrinfo sub-2400402_ses-20170227_3D_Flair_fast3DTRA_brainmask.nii.gz
: 1722007689:0;HR_combined_prettierEDSR.nii.gz HR_FLAIR_mbSRRpy.nii.gz sub-2400402_ses-20170227_3D_Flair_fast3DTRA_brainmask.nii.gz
: 1722007712:0;mrview HR_combined_prettierEDSR.nii.gz HR_FLAIR_mbSRRpy.nii.gz sub-2400402_ses-20170227_3D_Flair_fast3DTRA_preproc.nii.gz
: 1722008057:0;for IM in $(ls LR_FLAIR_prettier/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/.nii.gz//')\
    echo ${IM_BN}\
done
: 1722008166:0;mkdir LR_FLAIR_prettier_masks\
for IM in $(ls LR_FLAIR_prettier/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/.nii.gz//')\
    hd-bet -i LR_FLAIR_prettier_masks/${IM_BN}.nii.gz -o LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null\
    rm LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz\
    mv LR_FLAIR_prettier_masks/${IM_BN}_bet_mask.nii.gz LR_FLAIR_prettier_masks/${IM_BN}_brainmask.nii.gz\
done
: 1722008211:0;for IM in $(ls LR_FLAIR_prettier/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/.nii.gz//')\
    hd-bet -i ${IM} -o LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null\
    rm LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz\
    mv LR_FLAIR_prettier_masks/${IM_BN}_bet_mask.nii.gz LR_FLAIR_prettier_masks/${IM_BN}_brainmask.nii.gz\
done
: 1722008272:0;ls LR_FLAIR_prettier_masks
: 1722008315:0;$(ls LR_FLAIR_prettier/*.nii.gz)
: 1722008329:0;ls LR_FLAIR_prettier/*.nii.gz
: 1722008345:0;IM=LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRSag3mm3DSAG_prettierEDSR.nii.gz
: 1722008353:0;IM_BN=$(basename ${IM} | sed 's/.nii.gz//')
: 1722008362:0;hd-bet -i ${IM} -o LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz -device cpu -mode fast -tta 0
: 1722008672:0;CASE=0030403\
DATE=20120507
: 1722008685:0;cd ${PRO_DIR}/sub-${CASE}/ses-${DATE}/anat
: 1722008701:0;ls
: 1722008711:0;mkdir LR_FLAIR_prettier
: 1722008793:0;for IM in $(ls LR_FLAIR_hmatch/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/_preproc.nii.gz//')\
    echo ${IM_BN}\
done
: 1722008850:0;for IM in $(ls LR_FLAIR_hmatch/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/_preproc.nii.gz//')\
    ~/PRETTIER/prettier_mri.py --LR-input ${IM} --model-name EDSR --output LR_FLAIR_prettier/${IM_BN}_prettierEDSR.nii.gz --batch-size 4\
done
: 1722009021:0;mkdir LR_FLAIR_prettier_masks\
for IM in $(ls LR_FLAIR_prettier/*.nii.gz); \
do\
    IM_BN=$(basename ${IM} | sed 's/.nii.gz//')\
    hd-bet -i ${IM} -o LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null\
    rm LR_FLAIR_prettier_masks/${IM_BN}_bet.nii.gz\
    mv LR_FLAIR_prettier_masks/${IM_BN}_bet_mask.nii.gz LR_FLAIR_prettier_masks/${IM_BN}_brainmask.nii.gz\
done
: 1722010277:0;SCR_DIR=/home/vlab/MS_MRI_processing/scripts
: 1722010442:0;mrview LR_FLAIR_prettier/sub-0030403_ses-20120507_T2WFLAIR2D*
: 1722010513:0;HR_grid=HRgrid_1mm.nii.gz
: 1722010529:0;${SCR_DIR}/align_combine.py 
: 1722010585:0;[200~${SCR_DIR}/align_combine.py $(ls LR_FLAIR_prettier/*.nii.gz) ${HR_grid} HR_combined_prettierEDSR.nii.gz -masks $(ls LR_FLAIR_prettier_masks/*.nii.gz) -iter 2

${SCR_DIR}/align_combine.py $(ls LR_FLAIR_prettier/*.nii.gz) ${HR_grid} HR_combined_prettierEDSR.nii.gz -masks $(ls LR_FLAIR_prettier_masks/*.nii.gz) -iter 2
~/PRETTIER/prettier_mri.py --LR-input LR_FLAIR_hmatch/sub-2400402_ses-20170227_FLAIRTra3mm3DTRA_preproc.nii.gz --model-name EDSR --output LR_FLAIR_prettier/sub-2400402_ses-20170227_FLAIRTra3mm3DTRA_prettierEDSR.nii.gz --batch-size 3


export PYTHONPATH=/home/vlab/mrtrix3/lib:$PYTHONPATH\