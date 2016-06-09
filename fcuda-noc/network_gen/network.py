#!/usr/bin/python
import math
import logging
import sys
from util import pos_in_list
from node import Node, Compute, Memory, Router

class Network(object):
  def __init__(self):
    self.nodes = []
    self.num_ports = 5   # number of ports per router
    self.routers_logic = ""

  def __str__(self):
    st = ""
    st += "Network:\n"
    st += "  num_ports: %d\n" % self.num_ports
    st += "  nodes:\n" 
    for i in self.nodes:
      st += "%s\n" % i.__str__(4)

    return st

  def findNode(self,nid):
    """Find node in network by ID."""
    results = filter(lambda x: x.getNodeNum() == nid, self.nodes)
    if (len(results) == 1):
      return results[0]
    elif (len(results) == 0):
      # No node found with id=nid
      return None
    else:
      # Multiple results found in search for nid
      return None

  def addNode(self, n):
    self.nodes.append(n)

  def addNodes(self,n):
    self.nodes.extend(n)

  def numRouters(self):
    return sum(isinstance(x,Router) for x in self.nodes)

  def numTotalNodes(self):
    return len(self.nodes)

  def getFieldSize(self):
    return 1 << ((self.numTotalNodes()).bit_length())

  def numMemNodes(self):
    return sum(isinstance(x,Memory) for x in self.nodes)

  def numComputeNodes(self):
    return sum(isinstance(x,Compute) for x in self.nodes)

  def numNonRouterNodes(self):
    return sum(isinstance(x,Compute) + isinstance(x,Memory) for x in self.nodes) 

  def getListNodes(self):
    return [x for x in self.nodes]

  def buildRoutersLogic(self):

    for i in xrange(self.numComputeNodes()):
      self.routers_logic += "wire [`IO_WIDTH - 1 : 0] node_i_%d; // compute node input\n" % i
      self.routers_logic += "wire [`IO_WIDTH - 1 : 0] node_o_%d; // compute node output\n" % i

    for i in xrange(self.numComputeNodes(), self.numNonRouterNodes()):
      self.routers_logic += "wire [`IO_WIDTH - 1 : 0] node_i_%d; // memory input\n" % i
      self.routers_logic += "wire [`IO_WIDTH - 1 : 0] node_o_%d; // memory output\n" % i

    for i in xrange(self.numNonRouterNodes(), self.numTotalNodes()):
      self.routers_logic += "wire[`TOTAL_WIDTH - 1: 0] r%d_in;  // router input\n" % i
      self.routers_logic += "wire[`TOTAL_WIDTH - 1: 0] r%d_out; // router output\n" % i

    for router in filter(lambda x: isinstance(x,Router), self.nodes):
      for neighbor in router.getNeighbors():
        for k in ["in", "out"]:
          self.routers_logic += "wire [`IO_WIDTH - 1 : 0] r%d_%s_%d;\n" % (router.getNodeNum(), k, neighbor.getNodeNum())

    self.routers_logic += "// connect router inputs and outputs to nodes and other routers\n"
    routers = filter(lambda x: isinstance(x,Router), self.nodes)
    for router in routers:
      rid = router.getNodeNum()
      for neighbor in router.getNeighbors():
        nid = neighbor.getNodeNum()
        if (isinstance(neighbor,Router)):
          self.routers_logic += "assign r%d_in_%d = r%d_out_%d;\n" % (rid, nid, nid, rid)
        else:
          self.routers_logic += "assign r%d_in_%d = node_o_%d;\n" % (rid, nid, nid)
          self.routers_logic += "assign node_i_%d = r%d_out_%d;\n" % (nid, rid, nid)

    self.routers_logic += "// join router inputs from individual wires\n"
    for router in routers:
      rid = router.getNodeNum()
      self.routers_logic += "assign r%d_in = { " % rid
      self.routers_logic += ",".join(map(lambda x: "r%d_in_%d" % (rid, x.getNodeNum()), reversed(router.getNeighbors()))) + "};\n"

    self.routers_logic += "\n// separate router outputs into individual wires\n"
    for router in routers:
      rid = router.getNodeNum()
      for neighbor in router.getNeighbors():
        nid = neighbor.getNodeNum()
        pos = pos_in_list(router.getNeighbors(),neighbor)
        self.routers_logic += "assign r%d_out_%d = r%d_out[(%d + 1) * `IO_WIDTH - 1 : %d * `IO_WIDTH];\n" % (rid, nid, rid, 
            pos, pos)

    return self.routers_logic


  def getMemAddress(self):
    mn = filter(lambda x: isinstance(x,Memory),self.nodes)
    if (len(mn)) != 1:
      logging.error("Multiple memory nodes detected!")
    else:
      return str(mn[0].getNodeNum())


  def buildRoutingTables(self):
    """Build routing tables for each node"""
    for i in self.nodes:
        i.fillRoutingTable(self)

  def buildNetwork(self, width, height):
    num_cores = width * height

    # create nodes
    compute_nodes = []
    for i in range(0, num_cores):
        compute_nodes.append(Compute(i))

    M = Memory(num_cores)

    router_nodes = []
    for i in range(0, num_cores):
        router_nodes.append(Router(1 + i + num_cores))

    # connect each compute node to its router
    for i in range(0, num_cores):
        compute_nodes[i].addNeighbor(router_nodes[i])
    # connect final node to memory controller
    M.addNeighbor(router_nodes[num_cores - 1])

    # connect each router to its surrouding nodes.
    # The order here (which router connects to which router first) 
    # really does not matter to the correctness of the network 
    # (in term of delivering correct result), but it will affect the 
    # performance (in term of clock cycles and memory accesses)
    # since the packets traverse differently, hence leads to
    # different network congestion.
    # Be creative when creating your own topology!
    # The code below connects routers in mesh-style
    for i in range(0, height):
        for j in range(0, width):
            # final router node is connected to memory node
            if j + i * width == num_cores - 1:
                router_nodes[j + i * width].addNeighbor(M)

            # each router connects to its respective compute node
            router_nodes[j + i * width].addNeighbor(compute_nodes[j + i * width])

            # top node, same column
            if i > 0:
                router_nodes[j + i * width].addNeighbor(router_nodes[j + (i - 1) * width])
            # left node, same row
            if j > 0:
                router_nodes[j + i * width].addNeighbor(router_nodes[j - 1 + i * width])
            # right node, same row
            if j < width - 1:
                router_nodes[j + i * width].addNeighbor(router_nodes[j + 1 + i * width])
            # bottom node, same column
            if i < height - 1:
                router_nodes[j + i * width].addNeighbor(router_nodes[j + (i + 1) * width])
      
    list_nodes = []
    for i in range(0, num_cores):
        list_nodes.append(compute_nodes[i])
    list_nodes.append(M)
    for i in range(0, num_cores):
        list_nodes.append(router_nodes[i])
    self.addNodes(list_nodes)

    self.buildRoutingTables()

