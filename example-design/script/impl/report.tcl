#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

# timing
set wns_number [get_property STATS.WNS [get_runs impl_1]]
set tns_number [get_property STATS.TNS [get_runs impl_1]]
set whs_number [get_property STATS.WHS [get_runs impl_1]]
set ths_number [get_property STATS.THS [get_runs impl_1]]
puts "WNS(ns) = $wns_number TNS(ns) = $tns_number WHS(ns) = $whs_number THS(ns) = $ths_number"

# utilization
report_utilization -append -file project_1.runs/impl_1/design_1_wrapper_utilization_hier_summary.rpt -hierarchical -hierarchical_depth 3
report_utilization -append -file project_1.runs/impl_1/design_1_wrapper_utilization_hier_detail.rpt -hierarchical -hierarchical_depth 7
