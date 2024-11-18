/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


#define RO 0 // Resource Optimized (8-pixel implementation)
#define NO 1 // Normal Operation (1-pixel implementation)

// port widths
#define INPUT_PTR_WIDTH 32
#define OUTPUT_PTR_WIDTH 512


#define CTL_WIDTH 64
#define FCDT_WIDTH 32
#define MDDT_WIDTH 512
#define NWDT_WIDTH 512
#define IF_NUM 2
#define PACKET_PIX 256/4
#define PACKET_SIZE 256/4
#define CHANNEL 1
#define INPUT_NUM 2          // input frame num 
#define CH_NUM 8 // input channel num
#define FUNC_TYPE 0 //0:image, 1:tensor
#define CONV_ADP_MODULE_ID 0x0000F1C2
#ifndef CONV_ADP_LOCAL_VERSION
#define CONV_ADP_LOCAL_VERSION 0xDEADBEEF
#endif

// For Nearest Neighbor & Bilinear Interpolation, max down scale factor 2 for all 1-pixel modes, and for upscale in x
// direction
#define MAXDOWNSCALE 2

#define RGBB 1
#define GRAYY 0
/* Interpolation type*/
#define INTERPOLATION 1
// 0 - Nearest Neighbor Interpolation
// 1 - Bilinear Interpolation
// 2 - AREA Interpolation

/* Input image Dimensions */
#define WIDTH 3840  // Maximum Input image width
#define HEIGHT 2160 // Maximum Input image height

/* Output image Dimensions */
#define NEWWIDTH 1920  // Maximum output image width
#define NEWHEIGHT 1080 // Maximum output image height

