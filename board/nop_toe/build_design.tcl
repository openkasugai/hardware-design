#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

#
# create_project.tcl  Tcl script for creating project
set DIR [exec pwd]
set     project_name        "$DIR/project_1/project_1.xpr"

# Open Project
#
open_project $project_name

# Specify Kernel IP Repository
update_ip_catalog -rebuild
set_property  ip_repo_paths {../../ip} [current_project]
update_ip_catalog

add_files -fileset sources_1 -norecurse ../../ip/common/src/axis_buf.v
add_files -fileset sources_1 -norecurse ../../ip/common/src/packet_fifo.v
add_files -fileset sources_1 -norecurse ../../ip/function_ctrl/src/function_ctrl.v
add_files -fileset sources_1 -norecurse ../../functions/nop_st/nop_st_wrapper.v
add_files -fileset sources_1 ../../functions/nop_st/nop_st/hls/impl/verilog
add_files -fileset sources_1 -norecurse ../common/src/axis_sink.v

# Set xdc
add_files -fileset constrs_1 -norecurse pblock.xdc

# Reconfigure Block Design
source design_1.tcl
regenerate_bd_layout
save_bd_design
set design_bd_name [get_bd_designs]
generate_target all [get_files $design_bd_name.bd]
make_wrapper -files [get_files $design_bd_name.bd] -top -import
set_property top design_1_wrapper [current_fileset]

# Save Design
save_bd_design
update_compile_order -fileset sources_1

# Close Project
#
close_project
