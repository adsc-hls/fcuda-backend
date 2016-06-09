connect arm hw
rst -srst
fpga -f [lindex $argv 0]
source [lindex $argv 1]
ps7_init
ps7_post_config

