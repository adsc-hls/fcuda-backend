################################################################################
##    FCUDA
##    Copyright (c) <2016>
##    <University of Illinois at Urbana-Champaign>
##    <University of California at Los Angeles>
##    All rights reserved.
##
##    Developed by:
##
##        <ES CAD Group & IMPACT Research Group>
##            <University of Illinois at Urbana-Champaign>
##            <http://dchen.ece.illinois.edu/>
##            <http://impact.crhc.illinois.edu/>
##
##        <VAST Laboratory>
##            <University of California at Los Angeles>
##            <http://vast.cs.ucla.edu/>
##
##        <Hardware Research Group>
##            <Advanced Digital Sciences Center>
##            <http://adsc.illinois.edu/>
################################################################################

#!/usr/bin/python

import logging
import sys

def pos_in_list(l,i):
  """pos_in_list
       l: list
       i: item possibly in list
       return: index of i in l if i is in l
               else, return -1
  """

  res = [pos for pos,item in enumerate(l) if item == i]
  if len(res) == 1: return res[0]
  print "error in pos_in_list"
  return -1


