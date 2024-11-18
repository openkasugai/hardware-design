/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/


#define RO 0 // Resource Optimized (8-pixel implementation)
#define NO 1 // Normal Operation (1-pixel implementation)

// port widths
#define INPUT_PTR_WIDTH 32
#define OUTPUT_PTR_WIDTH 32

#define CTL_WIDTH 64
#define FCDT_WIDTH 32
#define NWDT_WIDTH 512
#define IF_NUM 2
#define PACKET_PIX 1460/4
#define PACKET_SIZE 1460/4
#define FIL_RSZ_MODULE_ID 0x0000F2C2
#ifndef FIL_RSZ_LOCAL_VERSION
#define FIL_RSZ_LOCAL_VERSION 0xDEADBEEF
#endif


// For Nearest Neighbor & Bilinear Interpolation, max down scale factor 2 for all 1-pixel modes, and for upscale in x
// direction
#define MAX_DOWNSCALE 10

#define RGBB 1
#define GRAYY 0
/* Interpolation type*/
#define INTERPOLATION 1
// 0 - Nearest Neighbor Interpolation
// 1 - Bilinear Interpolation
// 2 - AREA Interpolation

/* Input image Dimensions */
#define IN_WIDTH 3840  // Maximum Input image width
#define IN_HEIGHT 2160 // Maximum Input image height

/* Output image Dimensions */
#define OUT_WIDTH 1920  // Maximum output image width
#define OUT_HEIGHT 1080 // Maximum output image height

#define WINDOW_SIZE 5
