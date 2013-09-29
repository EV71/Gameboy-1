# 
# Synthesis run script generated by Vivado
# 

  set_param gui.test TreeTableDev
create_project -in_memory -part xc7vx485tffg1761-2
set_property board xilinx.com:virtex7:vc707:2.0 [current_project]
set_param project.compositeFile.enableAutoGeneration 0
read_verilog -sv /Gameboy/WHACKAMOLE/easy/easy.srcs/sources_1/new/top.sv
read_xdc /Gameboy/WHACKAMOLE/easy/easy.srcs/constrs_1/new/top.xdc
set_property used_in_implementation false [get_files /Gameboy/WHACKAMOLE/easy/easy.srcs/constrs_1/new/top.xdc]

set_param synth.vivado.isSynthRun true
set_property webtalk.parent_dir /Gameboy/WHACKAMOLE/easy/easy.data/wt [current_project]
set_property parent.project_dir /Gameboy/WHACKAMOLE/easy [current_project]
synth_design -top top -part xc7vx485tffg1761-2
write_checkpoint top.dcp
report_utilization -file top_utilization_synth.rpt -pb top_utilization_synth.pb
