# Run PRETTIER in server to speed it up
GPUID=3

# Processed MRI dir
PRO_DIR=/data/home/dlorena/PELT_LR_FLAIR

for HM_DIR in $(ls -d ${PRO_DIR}/sub*/*/anat/LR_FLAIR_hmatch);
do
    echo "-----------------------------------------------------------------------"
    IMDIR=$(dirname ${HM_DIR})
    SR_DIR=${IMDIR}/LR_FLAIR_prettier

    echo "Creating ${SR_DIR}"
    mkdir -p ${SR_DIR}

    # Run PRETTIER with EDSR
    for IM in $(ls ${HM_DIR}/*.nii.gz); 
    do
        IM_BN=$(basename ${IM} | sed 's/_preproc.nii.gz//')
        echo ${IM_BN}

        if [[ ! -f ${SR_DIR}/${IM_BN}_prettierEDSR.nii.gz ]]; 
        then
            ~/PRETTIER/prettier_mri.py --input ${IM} --model-name EDSR --output ${SR_DIR}/${IM_BN}_prettierEDSR.nii.gz --batch-size 12 --gpu-id ${GPUID} --quiet
        else
            echo "${SR_DIR}/${IM_BN}_prettierEDSR.nii.gz already exists"
        fi
    done

done
