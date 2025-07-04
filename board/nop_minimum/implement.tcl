#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

#
# implementation.tcl  Tcl script for implementation
#
set DIR [exec pwd]
set     project_name        "$DIR/project_1/project_1.xpr"
#
# Open Project
#
open_project $project_name
#
# Run Synthesis
#
reset_run synth_1
launch_runs synth_1 -job 20
wait_on_run synth_1
#
# Run Implementation
#
reset_run impl_1
launch_runs impl_1 -job 20
wait_on_run impl_1
open_run    impl_1
#
# Write Bitstream File
#
launch_runs impl_1 -to_step write_bitstream -job 20
wait_on_run impl_1
#
# Generate MSC
#
#write_cfgmem -force -format mcs -interface spix4 -size 128 -loadbit "up 0x01002000 $DIR/toe_board/project_1/project_1.runs/impl_1/design_1_wrapper.bit" -file "$DIR/toe_board/project_1/project_1.runs/impl_1/design_1_wrapper.mcs"
#wait_on_run impl_1
#
# Close Project
#
close_project
