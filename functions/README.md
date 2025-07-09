# Functions

## Directories

```
 functions -+- nop_st      : HLS nop axis function
            +- nop_mm      : HLS nop axi function
            +- vec_fp_inc  : HLS vector fp32 increment function
            +- template    : common makefile
```

## HLS functions and function wrapper.

The I/F supported by the HLS function is as follows
- AXI stream data input and output
- AXI data access input and output with `direct` buffer address input.
- require ap\_ctrl
- static parameter configured by axilite slave

The function wrapper is automatically generated with the following settings. 
- input and output port number:
  - IPORT\_NUM, OPORT\_NUM
- whether the input/output port is mmapped or not
  - IPORT\_IS\_MM, OPORT\_IS\_MM
- whether or not the output size is updated by the function
  - OPORT\_HEADER\_UPDATE
- specifying other port associations with `bind`

Please refer Makefiles of sample functions.

