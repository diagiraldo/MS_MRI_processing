#!/usr/bin/env python3
# Diana Giraldo
# March 2023

import argparse
import os, sys

import numpy as np
import nibabel as nib

def decompose_affine(v2w, scaling):
    A = v2w[:3, :3]
    b = v2w[:3, 3]
    S = np.diag(np.append(scaling, 1.)).astype(np.float32)
    R = np.block([[A, np.zeros((3, 1))],
                  [np.zeros((1, 3)), 1.]]).astype(np.float32) @ np.linalg.inv(S)
    T = np.block([[np.eye(3), b.reshape(-1,1)],
                  [np.zeros((1, 3)), 1.]]).astype(np.float32)
    return T, R, S

def main(args=None):
    
    # Get inputs
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=str, required=True)
    parser.add_argument('--reference', type=str, required=True)
    parser.add_argument('--output', type=str, required=True)
    parser.add_argument('--ro-matrix', type=str)
    parser.add_argument('--realign-grid', action='store_true', default=False)
    parser.add_argument('--verbose', action='store_true', default=False)
    
    args = parser.parse_args(args if args is not None else sys.argv[1:])
    
    # Check arguments
    if not os.path.isfile(args.input):
        raise ValueError('Input image file does not exist.')
    if not os.path.isfile(args.reference):
        raise ValueError('Reference image file does not exist.')
    
    # Get input image orientation
    IM = nib.load(args.input)
    im_ori = nib.orientations.io_orientation(IM.affine)
    if args.verbose:
        print('Image orientation:', nib.aff2axcodes(IM.affine))

    # Get reference orientation
    REF = nib.load(args.reference)
    ref_ori = nib.orientations.io_orientation(REF.affine)
    if args.verbose:
        print('Reference orientation:', nib.aff2axcodes(REF.affine))
    
    # Orientation transform from reference to input
    or_ref2in = nib.orientations.ornt_transform(ref_ori, im_ori)
    
    # Affine transform from input to reference
    aff_in2ref = nib.orientations.inv_ornt_aff(
        or_ref2in,
        np.array(REF.shape).astype(np.int32)
    )
    or_in2ref = nib.orientations.io_orientation(aff_in2ref)
    
    # Apply reorientation
    RO_IM = IM.as_reoriented(or_in2ref)
    
    if args.realign_grid:

        imvox = np.array(RO_IM.header.get_zooms()).astype(np.float32)
        T_im,R_im,S_im = decompose_affine(RO_IM.affine, imvox)

        refvox = np.array(REF.header.get_zooms()).astype(np.float32)
        T_ref,R_ref,S_ref = decompose_affine(REF.affine, refvox)

        tmprefvox = np.dot(np.linalg.inv(np.abs(aff_in2ref[:3,:3])), refvox)
        extra_shift = 0
        if args.verbose:
            print('Extra shift:', extra_shift)
        shift = T_im[:3,3] + extra_shift
        new_T = np.block([[np.eye(3), shift.reshape(-1,1)],
                      [np.zeros((1, 3)), 1.]]).astype(np.float32)
        new_imaff = new_T @ R_ref @ S_im
        out = nib.Nifti1Image(RO_IM.get_fdata(), new_imaff, RO_IM.header)
    else:
        out = RO_IM
    
    # Save reoriented image
    nib.save(out, args.output)
    
    # Save reorientation affine transform 
    if args.ro_matrix is not None:
        np.savetxt(args.ro_matrix, aff_in2ref)
        

#---------------------------------------------
if __name__ == '__main__':
    main()