#!/usr/bin/python
import logging
import sys
from util import pos_in_list

class RoutingTable(object):
  """Routing Table class"""
  def __init__(self):
    # single routing table has 4 x 32 bits 
    # For simplicity we will represent this as
    # list of 4 x (list of 32 x 1 )  items
    self.num_fields = 4

    # number of bits --this can be changed later 
    # depending on the size of the network
    # log2(num_compute_nodes + num_memory_node + num_router_nodes)
    self.field_size = 32    
    self.mapping = []

  def setFieldSize(self, field_size_val):
    self.field_size = field_size_val

  def printMapping(self):
    """ Print routing table mapping -- for debugging"""
    for i in self.mapping:
      print str(i['dest']) + " - " + str(i['outport'])

  def addRoute(self, dest, outport):
    """ Add a route to routing table mapping """
    # if port doesn't exist, just skip it
    if (outport != -1):
      self.mapping.append({'dest':dest, 'outport':outport})

  def getBinaryTable(self):
    """Get the table in binary (as a list of lists of 0s/1s)"""
    # print table in binary
    table = []
    [table.append([0] * self.field_size) for i in xrange(self.num_fields)]
    for i in self.mapping:
      table[i['outport']][i['dest']] = 1
    return table

  def getPackedTable(self): 
    """Get table in packed integer form"""
    result = [0] * self.num_fields
    for idx, val in enumerate(self.mapping):
      result[val['outport']] |= 1 << val['dest']
    return result

  def getVerilogHexTable(self):
    """ Get table in hex form suitible for printing in Verilog """
    table = self.getPackedTable()
    st = ""
    for i in table:
      st =  "%0*x" % (self.field_size/4, i) + st
    return st

  def getCommentHexTable(self):
    """ Get table in hex form suitible for printing in Verilog """
    table = self.getPackedTable()
    st = ""
    for i in table:
      st =  "0x%0*x, " % (self.field_size/4, i) + st
    return st

  def getHexTable(self, indent = 0):
    """ Get table in hex form """
    table = self.getPackedTable()
    st = ""
    for i in table:
      st += " "*indent + "0x%0*x\n" % (self.field_size/4, i)
    return st

  def printHexTable(self):
    """ Print table in hex form """
    print self.getHexTable()
