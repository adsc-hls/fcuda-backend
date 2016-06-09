set proj_name [lindex $argv 0]
open_hw_design ${proj_name}.hdf
create_sw_design ${proj_name} -os standalone -proc ps7_cortexa9_0
generate_bsp -sw ${proj_name}
