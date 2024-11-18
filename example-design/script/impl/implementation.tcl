#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

#
# implementation.tcl  Tcl script for implementation
#
#set     project_directory   [./project_1.xpr]
set     project_name        "project_1"
#
# Open Project
#
open_project $project_name
#
# Run Synthesis
#
reset_run synth_1
launch_runs synth_1 -job 4
wait_on_run synth_1
#
# Run Implementation
#
reset_run impl_1
launch_runs impl_1 -job 4
wait_on_run impl_1
open_run    impl_1
#
# Report
#
source report.tcl
#
# Write Bitstream File
#
launch_runs impl_1 -to_step write_bitstream -job 4
wait_on_run impl_1
# Write MCS File
write_cfgmem -force -format mcs -interface spix4 -size 128 -loadbit "up 0x01002000 project_1.runs/impl_1/design_1_wrapper_tandem1.bit" -file "project_1.runs/impl_1/design_1_wrapper_tandem1.mcs"
#
# Close Project
#
close_project
