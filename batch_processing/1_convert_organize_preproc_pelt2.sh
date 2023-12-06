#!/usr/bin/zsh

# Read T2-FLAIR and structural T1 in DICOM, convert to nifti
# and organize them in a folder following BIDS... for second set of Pelt data
# Diana Giraldo, Dec 2023
# It calls convert_organize.sh for each image

# Scripts dir
SCR_DIR=/home/vlab/MS_MRI_processing

# DICOM dir
DCM_DIR=/mnt/extradata/MSPELT_2/remaining_DCM
# Acquisition info dir 
ACQ_DIR=/mnt/extradata/MSPELT_2/remaining_acquisition_info

# MRI dir to organize raw images
MRI_DIR=/home/vlab/MS_proj/MS_MRI_2

# Loop over cases/subject
for CASE in $(ls ${DCM_DIR});
do
    echo "------------------------------------------------"
    echo "CASE: ${CASE}"
    
    # Loop over session per case
    for SESS in $(ls ${DCM_DIR}/${CASE});
    do
        echo " Session: ${SESS}"

        # Loop over sT1 and Flair DICOM folders
        for  IN_DCM in $(ls -d ${DCM_DIR}/${CASE}/${SESS}/*(sT1|[Ff][Ll][Aa][Ii][Rr])*/); 
        do
            IMGBN=$(basename ${IN_DCM})
            echo "  Image basename: ${IMGBN}"

            # .json file with DICOM info
            JSFILE=$(find ${ACQ_DIR}/${CASE}/${SESS}/${IMGBN}_info*.json | head -n 1)
            #echo "  Info file: ${JSFILE}"

            # Extract date
            IM_DATE=$( cat ${JSFILE} | grep -Po '"Instance.Creation.Date":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/\///g' | sed 's/,//' )
            #echo "  Date: ${IM_DATE}"

            # Extract Series Description and define (data)image type (just to double check)
            IM_DESCR=$( cat ${JSFILE} | grep -Po '"Series.Description":.*?[^\\]",' | sed 's/[^ ]* //' )
            #echo "  Image description: ${IM_DESCR}"
            if $(echo ${IM_DESCR} | grep -q -E "T2|T1|[Ff][Ll][Aa][Ii][Rr]"); then
                IM_TYPE=anat
            fi
            if $(echo ${IM_DESCR} | grep -q -E "DWI"); then
                IM_TYPE=dwi            # remove tmp dir 
            rm -r ${TMP_DIR}
            fi
            #echo "  Image type: ${IM_TYPE}"

            # Extract acquisition type and orientation
            ACQ_TYPE=$( cat ${JSFILE} | grep -Po '"MR.Acquisition.Type":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )
            ACQ_ORI=$( cat ${JSFILE} | grep -Po '"SliceOrientation":.*?[^\\]",' | cut -d" " -f2 | sed 's/\"//g' | sed 's/,//' )

            # Output folder
            OUT_DIR=${MRI_DIR}/sub-${CASE}/ses-${IM_DATE}/${IM_TYPE}
            mkdir -p ${OUT_DIR}

            # Output basename
            OUT_NAME=sub-${CASE}_ses-${IM_DATE}_${IMGBN}_${ACQ_TYPE}${ACQ_ORI}
            #echo "  new basename ${OUT_NAME}"

            # Make temporary directory
            TMP_DIR=$(mktemp -d)

            # convert to nifti
            mrconvert ${IN_DCM} ${TMP_DIR}/raw.nii.gz -config RealignTransform 0

            # Denoise 
            echo "   Denoising..."
            DenoiseImage -d 3 -n Rician -i ${TMP_DIR}/raw.nii.gz -o ${TMP_DIR}/dn.nii.gz
            # Calculate absolute value to remove negatives
            ImageMath 3 ${TMP_DIR}/dnabs.nii.gz abs ${TMP_DIR}/dn.nii.gz
            mv ${TMP_DIR}/dnabs.nii.gz ${TMP_DIR}/dn.nii.gz    

            # Estimate Brain mask 
            echo "   HD-BET..."
            hd-bet -i ${TMP_DIR}/dn.nii.gz -o ${TMP_DIR}/bet.nii.gz -device cpu -mode fast -tta 0 > /dev/null
            rm ${TMP_DIR}/bet.nii.gz
            mv ${TMP_DIR}/bet_mask.nii.gz ${TMP_DIR}/brainmask.nii.gz                    

            # Biasfield correction N4
            echo "   Biasfield correction..."
            N4BiasFieldCorrection -d 3 -i ${TMP_DIR}/dn.nii.gz -o ${TMP_DIR}/dn_N4.nii.gz -x ${TMP_DIR}/brainmask.nii.gz

            # Move to output folder
            mv ${TMP_DIR}/dn_N4.nii.gz ${OUT_DIR}/${OUT_NAME}_preproc.nii.gz
            mv ${TMP_DIR}/brainmask.nii.gz ${OUT_DIR}/${OUT_NAME}_brainmask.nii.gz
            cp ${JSFILE} ${OUT_DIR}/${OUT_NAME}.json

            echo "Pre-processed image in ${OUT_DIR}/${OUT_NAME}_preproc.nii.gz"

            # remove tmp dir 
            rm -r ${TMP_DIR}

        done

    done

done

