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


