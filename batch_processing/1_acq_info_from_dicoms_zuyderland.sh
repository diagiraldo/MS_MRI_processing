#!/usr/bin/zsh

# Extract acquisition info of each DICOM folder
# Diana Giraldo, Nov 2023

# DICOM dir
DCM_DIR=/mnt/extradata/MRI_Zuyderland/Output_3_9_2023
# Acquisition info dir 
ACQ_DIR=/mnt/extradata/MRI_Zuyderland/acquisition_info

# Loop over subjects
for CASE in $(ls ${DCM_DIR});
do
    echo "------------------------------------------------"
    echo "Case: ${CASE}"

    for SESS in $( ls ${DCM_DIR}/${CASE} ) ;
    do
        echo " Session: ${SESS}"

        for FOLDER in $( ls ${DCM_DIR}/${CASE}/${SESS} );
        do
            echo "  Folder: ${FOLDER}"

            IN_DCM=${DCM_DIR}/${CASE}/${SESS}/${FOLDER}

            ndcms=$(ls ${IN_DCM}/*.dcm | wc -l)
            echo ${ndcms} > ${ACQ_DIR}/${CASE}/${SESS}/ndcms_${FOLDER}.txt

            mkdir -p ${ACQ_DIR}/${CASE}/${SESS}/${FOLDER}

            for EX_DCM in $( ls ${IN_DCM}/*.dcm );
            do
                DCMBN=$(basename ${EX_DCM})
                dcminfo ${EX_DCM} -tag 0008 0005 -tag 0008 0008 -tag 0008 0012 -tag 0008 0020 -tag 0008 0022  -tag 0040 0244 -tag 0040 0245 -tag 0008 0060 -tag 0018 0087 -tag 0018 0084 -tag 0008 0070 -tag 0008 1090 -tag 0008 1010 -tag 0018 0015 -tag 0018 5100 -tag 0018 1020 -tag 0018 0023 -tag 0018 0024 -tag 0008 103E -tag 0018 1030 -tag 0018 0020 -tag 0018 0021 -tag 0018 0022 -tag 0008 0031 -tag 0008 0032 -tag 0008 0033 -tag 0018 9073 -tag 0018 9087 -tag 0018 9089 -tag 0020 0011 -tag 0020 0012 -tag 0020 0013 -tag 0018 0050 -tag 0018 0088 -tag 0018 1316 -tag 0018 0080 -tag 0018 0081 -tag 0018 0082 -tag 0018 1314 -tag 0018 1250 -tag 0018 1251 -tag 0018 0089 -tag 0018 0091 -tag 0018 0093 -tag 0018 0094 -tag 0018 0095 -tag 0018 1310 -tag 0018 1312 -tag 0028 0030 -tag 0028 0010 -tag 0028 0011 -tag 2001 100B -tag 0020 0037 -tag 2005 102A -tag 0040 1001 -tag 0020 0010 -tag 0010 0010 -tag 0010 0020 -tag 0010 0030 -tag 0010 0040 -tag 0020 0032 -tag 0020 0037 > ${ACQ_DIR}/${CASE}/${SESS}/${FOLDER}/${DCMBN%.dcm}.txt
            done        

        done

    done

done