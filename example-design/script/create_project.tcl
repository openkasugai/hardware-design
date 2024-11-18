#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

if { $::argc != 1 } {
    error "ERROR: Program \"$::argv0\" requires 1 arguments!, (${argc} given)\n"
}
set board_dir [lindex $::argv 0]
set_param board.repoPaths $board_dir

#
# create_project.tcl  Tcl script for creating project
set DIR [exec pwd]
set project_directory "$DIR/project_1"
set project_name "project_1"

# create project
create_project $project_name $project_directory -part xcu250-figd2104-2L-e

# select board
set_property board_part xilinx.com:au250:part0:1.3 [current_project]

# set implement options
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
