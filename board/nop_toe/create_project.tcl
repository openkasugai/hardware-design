#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

#
# create_project.tcl  Tcl script for creating project
set DIR [exec pwd]
set     project_directory  "$DIR/project_1"
set     project_name        "project_1"

# Create Project
create_project $project_name $project_directory -part xcu250-figd2104-2L-e

# Select Board
set_property board_part xilinx.com:au250:part0:1.3 [current_project]

# Set Implementation Options
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
