#!/usr/bin/python
import sys
from gen_hb import Bus_design

def usage():
    print """
    Usage:
      python gen_bus.py {benchmark_name} {unroll_degree} {mpart_degree}

      where:
        benchmark_name: the name of the benchmarks for testing
        unroll_degree: degree of thread-loop unrolling
        mpart_degree: degree of memory (CUDA shared memory) partition
    Example:
        python get_compute_latency.py matmul 2 2
    """

def main(argv):
    app = argv[1]
    unroll_degree = int(argv[2])
    mpart_degree = int(argv[3])
    
    # only care about unroll & memory partitioning
    bus_obj = Bus_design(
        app = app,
        num_cores_per_tile = 1,
        unroll_degree = unroll_degree,
        mpart_degree = mpart_degree,
        num_tiles_x = 1,
        num_tiles_y = 1,
        frequency = 5)
    f = open("compute_latency.txt", 'w')
    f.write(str(bus_obj.get_compute_latency()))
    f.close()

if __name__ == "__main__":
    print len(sys.argv)
    if len(sys.argv) < 4:
        print "Insufficient number of argument"
        usage()
        sys.exit(1)

    main(sys.argv)

