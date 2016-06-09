//============================================================================//
//    FCUDA
//    Copyright (c) <2016> 
//    <University of Illinois at Urbana-Champaign>
//    <University of California at Los Angeles> 
//    All rights reserved.
// 
//    Developed by:
// 
//        <ES CAD Group & IMPACT Research Group>
//            <University of Illinois at Urbana-Champaign>
//            <http://dchen.ece.illinois.edu/>
//            <http://impact.crhc.illinois.edu/>
// 
//        <VAST Laboratory>
//            <University of California at Los Angeles>
//            <http://vast.cs.ucla.edu/>
// 
//        <Hardware Research Group>
//            <Advanced Digital Sciences Center>
//            <http://adsc.illinois.edu/>
//============================================================================//

//
// Macros
//

/*
 * BOUNDS
 * index into array
 *   i = index
 *   k = width
 */
`define BOUNDS(i,k) (i + 1) * (k) - 1 : (i) * (k)

/*
 * PBOUNDS
 * index into array using partial-select bounds notation
 * Use this when you get the "Variable width select" error!
 *   params: index
 *   params: width
 */
`define PBOUNDS(index,width) (index + 1) * (width) - 1 -: (width)
`define mPBOUND(index,width) (index*2+1) * (width) - 1 -: (width)
/*
 * FIELD
 * bounds for field within wire bundle
 *   offset = offset
 *   width = width
 */
`define FIELD(offset, width) (offset + width - 1) : (offset)
