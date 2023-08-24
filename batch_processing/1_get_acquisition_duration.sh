# Processed MRI dir
PRO_DIR=DCM_imgs

for CASE in $(ls ${PRO_DIR})
do
    echo "-----------------------------------------"
    echo "Subject: ${CASE}"
    
    for SES in $( ls ${PRO_DIR}/${CASE} ); do
    echo "FOLDER ${SES}"

        for IM in $(ls -d ${PRO_DIR}/${CASE}/${SES}/*(FLAIR|flair|Flair)* ); do
            SEQ=$(basename ${IM})
            echo "SECQUENCE ${SEQ}"
            outxt=tmp_acq_duration/${CASE}_${SES}_${SEQ}.txt
            DCM=$(ls ${IM} | head -n 1 )
            #echo "MRSeriesMagneticFieldStrength"
            dcminfo ${IM}/${DCM} -tag 2001 1085 >> ${outxt}
            #echo "ScanningSequence"
            dcminfo ${IM}/${DCM} -tag 0018 0020 >> ${outxt}
            #echo "SequenceVariant"
            dcminfo ${IM}/${DCM} -tag 0018 0021 >> ${outxt}
            #echo "PulseSequenceName"
            dcminfo ${IM}/${DCM} -tag 0018 9005 >> ${outxt}
            #echo "EchoPulseSequence"
            dcminfo ${IM}/${DCM} -tag 0018 9008 >> ${outxt}
            #echo "InstanceCreation"
            dcminfo ${IM}/${DCM} -tag 0008 0012 >> ${outxt} 
            #echo "Acquisition Duration"
            dcminfo ${IM}/${DCM} -tag 0018 9073 >> ${outxt}
            dcminfo ${IM}/${DCM} -tag 0008 0012 -tag 0008 0060 -tag 0018 0087 -tag 0018 0084 -tag 0008 0070 -tag 0008 1090 -tag 0008 1010 -tag 0018 0015 -tag 0018 5100 -tag 0018 1020 -tag 0018 0023 -tag 0008 103E -tag 0018 1030 -tag 0018 0020 -tag 0018 0021 -tag 0018 0022 -tag 0008 0032 -tag 0020 0011 -tag 0020 0012 -tag 0018 0050 -tag 0018 0088 -tag 0018 1316 -tag 0018 0080 -tag 0018 0081 -tag 0018 0082 -tag 0018 1314 -tag 0018 1250 -tag 0018 1251 -tag 0018 0089 -tag 0018 0091 -tag 0018 0093 -tag 0018 0094 -tag 0018 0095 -tag 0018 1310 -tag 0018 1312 -tag 0028 0030 -tag 0028 0010 -tag 0028 0011 -tag 2001 100B -tag 0020 0037 >> ${outxt}

        done
    done
done


