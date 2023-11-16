#!/usr/bin/env python3
# Function to get slice orientation
# Diana Giraldo
# Nov 2023

import argparse
import os, sys

import numpy as np
import nibabel as nib

def main(args=None):
    
    # Get inputs
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=str, required=True)
    
    args = parser.parse_args(args if args is not None else sys.argv[1:])
    
    # Check arguments
    if not os.path.isfile(args.input):
        raise ValueError('Input image file does not exist.')
    
    # Get input image orientation
    IM = nib.load(args.input)
    im_ori = nib.orientations.io_orientation(IM.affine)
    #print(nib.aff2axcodes(IM.affine))
    ori = im_ori[:,0].astype(np.int32)
    #print(ori)
    if np.array_equal(ori, [0, 1, 2]):
        print("TRA")
    elif np.array_equal(ori, [1, 2, 0]):
        print("SAG")
    elif np.array_equal(ori, [0, 2, 1]):
       print("COR")

#---------------------------------------------
if __name__ == '__main__':
    main()