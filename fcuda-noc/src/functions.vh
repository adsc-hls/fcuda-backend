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

// Not really a header file - an include file that includes
// commonly used functions (log, log2)

// take the log2
function integer log2;
  input [31:0] value;
  begin
    value = value-1;
    for (log2=0; value>0; log2=log2+1)
      value = value>>1;
  end
endfunction

// see: 
// www.sunburst-design.com/papers/CummingsHDLCON2001_Verilog2001_rev1_3.pdf
// http://forums.xilinx.com/t5/Archived-ISE-issues/XST-bug-with-Verilog-constant-function/td-p/2684
// [Needs to be coded this way due to ise bug]

//define the clogb2 function
function integer clogb2;
  input [31:0] value;
  integer result;
  begin
    result = value - 1;
  for(clogb2 = 0; result > 0; clogb2 = clogb2 + 1)
    result = result>>1;
  end
endfunction
