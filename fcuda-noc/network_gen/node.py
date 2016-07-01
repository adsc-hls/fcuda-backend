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
from util import pos_in_list
from routingtable import RoutingTable
import re

class Node(object):
  """Node - top level generic class"""
  def __init__(self):
    self.node_num      = -1
    self.neighbors = []
    self.rtables   = []
    self.prtables = []

  def __str__(self, indent = 0):
    """Print a string representation of the node"""
    st = ""
    st += " "*indent + "Node:\n"
    st += " "*indent + "  NodeNum: %d\n" % self.getNodeNum()
    st += " "*indent + "  Neighbors:\n"
    for i in self.neighbors:
      st += " "*indent + "    " + str(i.getNodeNum()) + "\n"
    st += " "*indent + "  Routing Tables:\n"
    st += self.getAllRoutingTables(indent + 4)

    return st

  def getCommentRoute(self, rtype):
    """Return comment string routing table that is a easier to read for debugging"""
    if (rtype == "rtables"): rt = self.rtables
    if (rtype == "prtables"): rt = self.prtables
    if len(rt) == 0:
      print "Attempting to print routing tables that do not exist!"
      return "ERROR"
    else:
      tl = 0
      st = "// Routing tables: \n"
      for i in reversed(rt):
        tl += i.num_fields * i.field_size
        st += "// [port %d] " % rt.index(i)
        st += i.getCommentHexTable()
        st += "\n"
      return st

  def getFullRoute(self, rtype):
    """Return valid verilog for a routing table"""
    rt = None
    if (rtype == "rtables"):  rt = self.rtables
    if (rtype == "prtables"): rt = self.prtables

    if len(rt) == 0:
      print "Attempting to print Route tables that do not exist"
      return "ERROR"
    else:
      tl = 0
      st = ""
      # need to accumulate in reversed order since we are appending
      for i in reversed(rt):
        tl += i.num_fields * i.field_size
        st += i.getVerilogHexTable()
      st = str(tl) + "'h" + st
      return st

  def getAllRoutingTables(self, indent = 0):
    """Helper function to print routing tables per node"""
    st = ""
    for i in self.rtables:
      st +=  i.getHexTable(indent)
    if (len(self.prtables)>0):
      st += "\n" + " "*(indent-2) + "PrerouteTables:\n"
      for i in self.prtables:
        st += i.getHexTable(indent)
    return st

  def getNodeNum(self):
    return self.node_num

  def setNodeNum(self,num):
    self.node_num = num

  def setVerilogFile(self,vfile):
    self.verilog_file = vfile

  def getNeighbors(self):
    return self.neighbors

  def addNeighbor(self,neighbor):
    self.neighbors.append(neighbor)

  def addNeighbors(self,neighbors):
    self.neighbors.extend(neighbors)

  def doLookup(self, network, router_id, source_port_number, target_id):
    """BFS in network to find next hop"""
    from network import Network
    # first - get router Node
    router = network.findNode(router_id)
    target = network.findNode(target_id)

    if (router == None) or (target == None):
      return -1

    # now - find neighbors
    neighbors = list(router.getNeighbors())

    # now - remove one neighbor: port the request came in on
    src = neighbors[source_port_number]
    neighbors.remove(neighbors[source_port_number])

    # initialize Q to contain these other items
    Q = []
    for idx, val in enumerate(neighbors):
      Q.append({'nhop': idx, 'node':val})

    # set src as visited
    V = []
    V.append(src)

    # do something else
    nhop = -1

    while len(Q) > 0:
      item = Q.pop(0)
      nhop = item['nhop']
      if (item['node'] == target):
        return nhop
      else:
        V.append(item['node'])
        Q.extend([{'nhop':nhop, 'node':x} for x in item['node'].getNeighbors() if x not in V])
    return nhop

  def fillRoutingTable(self, network):
    from network import Network
    # assumes there is only one router per node!
    router_id = self.getNeighbors()[0].getNodeNum()
    router = network.findNode(router_id)
    rn = router.getNeighbors()
    source_port_number = pos_in_list(rn, self)
    self.rtables[0].setFieldSize(network.getFieldSize())
    for i in xrange(network.getFieldSize()):
      nhop_for_target = self.doLookup(network, router_id, source_port_number, i)
      self.rtables[0].addRoute(i, nhop_for_target)


class Router(Node):
  """Router"""
  def __init__(self, num = -1):
    super(Router,self).__init__()
    self.setNodeNum(num)
    self.num_ports = 5
    self.rtables.extend([RoutingTable() for i in xrange(self.num_ports)])
    self.prtables.extend([RoutingTable() for i in xrange(self.num_ports)])

  def fillRoutingTable(self, network):
    """Fill the routing table for a router"""
    for i in xrange(self.num_ports):
      self.rtables[i].setFieldSize(network.getFieldSize())
      for j in xrange(network.getFieldSize()):
        # Filling table entry for port i - entry j
        if (i  >= len(self.getNeighbors())):
          first_nhop = -1
        else:
          first_nhop = self.doLookup(network, self.getNodeNum() , i, j)
        nr = self.get_nhop_neighbor(i, first_nhop)
        if (isinstance(nr,Router)):
          # if nexthop leads to a router, then
          # get the nexthop from that position
          nr_id  = nr.getNodeNum()
          nr_pos = pos_in_list(nr.getNeighbors(), self)
          # do a second lookup
          second_nhop = self.doLookup(network, nr_id, nr_pos , j)

          # finally, add to routing table
          self.rtables[i].addRoute(j, second_nhop)
        else:
          # if nexthop is not a router, then there is no next-nexthop, and this
          # is really a don't-care - so we can do nothing
          self.rtables[i].addRoute(j, -1)

    # routers also have wrappers for pre-routing tables
    self.fillPreRoutingTable(network)

  def get_nhop_neighbor(self, src_port, nhop):
    """Helper method to get NextHop Node from port number"""
    i = -1
    n = self.getNeighbors()
    if (nhop >= src_port):
      i = nhop + 1
    else:
      i = nhop
    return n[i]

  def fillPreRoutingTable(self, network):
    """Fill the wrapper prerouting table"""
    for i in xrange(self.num_ports):
      self.prtables[i].setFieldSize(network.getFieldSize())
      for j in xrange(network.getFieldSize()):
        if (i >= len(self.getNeighbors())):
          first_nhop = -1
        else:
          first_nhop = self.doLookup(network, self.getNodeNum() , i, j)
        self.prtables[i].addRoute(j, first_nhop)

  def param(self, pname, pval):
    return ".%s(%s)" % (pname, pval)

class Memory(Node):
  """Memory node subclass"""
  def __init__(self, num = -1):
    super(Memory,self).__init__()
    self.setNodeNum(num)
    self.rtables.append(RoutingTable())

class Compute(Node):
  """Compute node subclass"""
  def __init__(self, num = -1):
    super(Compute,self).__init__()
    self.setNodeNum(num)
    self.rtables.append(RoutingTable())

