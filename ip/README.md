# Hardware IPs

## Directories

```
 ip -+- axi_reader       : read from the device memory for functions having AXI I/F
     +- axi_writer       : write stream data to the device memory for functions having AXI I/F
     +- common           : common sub modules for other IPs
     +- external         : OSS TOE (fpga-network-stack)
     +- function_ctrl    : glue logics of HLS functions and route_controller
     +- route_controller : connection control IP in FPGA
     +- stream_engine    : drive streaming DMA without host intervention
     +- toe_wrapper      : simplifies the user I/F of OSS TOE using the network_ip_ctrl module
```
