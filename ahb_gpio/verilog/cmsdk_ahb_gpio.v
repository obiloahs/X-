//-----------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from ARM Limited.
//
//            (C) COPYRIGHT 2010-2013 ARM Limited.
//                ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from ARM Limited.
//
//      SVN Information
//
//      Checked In          : $Date: 2013-01-21 13:52:45 +0000 (Mon, 21 Jan 2013) $
//
//      Revision            : $Revision: 234293 $
//
//      Release Information : Cortex-M System Design Kit-r1p0-00rel0
//
//-----------------------------------------------------------------------------

module cmsdk_ahb_gpio
 #(// Parameter to define valid bit pattern for Alternate functions
   // If an I/O pin does not have alternate function its function mask
   // can be set to 0 to reduce gate count.
   //
   // By default every bit can have alternate function  
   parameter  ALTERNATE_FUNC_MASK = 16'hFFFF,  //每个引脚都有备用功能

   // Default alternate function settings
   parameter  ALTERNATE_FUNC_DEFAULT = 16'h0000,  //但是都不用

   // By default use little endian
   parameter  BE                  = 0  //默认是小端
  )

// ----------------------------------------------------------------------------
// Port Definitions  端口定义
// ----------------------------------------------------------------------------
  (// AHB Inputs  ahb输入测
   input  wire                 HCLK,      // system bus clock
   input  wire                 HRESETn,   // system bus reset
   input  wire                 FCLK,      // system bus clock
   input  wire                 HSEL,      // AHB peripheral select  //外围选择是做什么的
   input  wire                 HREADY,    // AHB ready input
   input  wire  [1:0]          HTRANS,    // AHB transfer type
   input  wire  [2:0]          HSIZE,     // AHB hsize
   input  wire                 HWRITE,    // AHB hwrite
   input  wire [11:0]          HADDR,     // AHB address bus
   input  wire [31:0]          HWDATA,    // AHB write data bus

   input wire  [3:0]           ECOREVNUM,  // Engineering-change-order revision bits

   input wire  [15:0]          PORTIN,     // GPIO Interface input

   // AHB Outputs ahb输出
   output wire                 HREADYOUT, // AHB ready output to S->M mux
   output wire                 HRESP,     // AHB response  gpio模块是slave吗（应该是吧，dut是slave很正常）
   output wire [31:0]          HRDATA,

   output wire [15:0]          PORTOUT,    // GPIO output
   output wire [15:0]          PORTEN,     // GPIO output enable
   output wire [15:0]          PORTFUNC,   // Alternate function control  //这个信号和ALTERNATE_FUNC_DEFAULT作用相似

   output wire [15:0]          GPIOINT,    // Interrupt output for each pin//控制每个引脚的中断输出，比如说某一个引脚产生了中断，对应bit为拉高？
   output wire                 COMBINT);   // Combined interrupt

// ----------------------------------------------------------------------------
// Internal wires  内部两个模块之间的连接线
// ----------------------------------------------------------------------------

   wire [31:0]           IORDATA;    // I/0 read data bus
   wire                  IOSEL;      // Decode for peripheral外围编码的作用是什么
   wire  [11:0]          IOADDR;     // I/O transfer address  /和总线地址什么区别  为什么是12位宽的
   wire                  IOWRITE;    // I/O transfer direction
   wire  [1:0]           IOSIZE;     // I/O transfer size
   wire                  IOTRANS;    // I/O transaction
   wire [31:0]           IOWDATA;    // I/O write data bus

// ----------------------------------------------------------------------------
// Block Instantiations  小模块的实例
// ----------------------------------------------------------------------------
  // Convert（转换） AHB Lite protocol（协议） to simple I/O port interface
  cmsdk_ahb_to_iop    //ahb到ioport的桥接模块
    u_ahb_to_gpio  (
    // Inputs
    .HCLK         (HCLK),
    .HRESETn      (HRESETn),
    .HSEL         (HSEL),
    .HREADY       (HREADY),
    .HTRANS       (HTRANS),
    .HSIZE        (HSIZE),
    .HWRITE       (HWRITE),
    .HADDR        (HADDR),
    .HWDATA       (HWDATA),

    .IORDATA      (IORDATA),

    // Outputs
    .HREADYOUT    (HREADYOUT),
    .HRESP        (HRESP),
    .HRDATA       (HRDATA),
	
	//桥接模块到ioport的连线  
    .IOSEL        (IOSEL),          //负责告诉io模块
    .IOADDR       (IOADDR[11:0]),
    .IOWRITE      (IOWRITE),
    .IOSIZE       (IOSIZE),
    .IOTRANS      (IOTRANS),
    .IOWDATA      (IOWDATA));

  // GPIO module with I/O port interface
  cmsdk_iop_gpio #(
    .ALTERNATE_FUNC_MASK     (ALTERNATE_FUNC_MASK),
    .ALTERNATE_FUNC_DEFAULT  (ALTERNATE_FUNC_DEFAULT), // All pins default to GPIO  /GPIO所有引脚附加功能的的默认值（我有这功能，但是我不用）
    .BE                      (BE))
    u_iop_gpio  (
    // Inputs
    .HCLK         (HCLK),               //总线时钟
    .HRESETn      (HRESETn),			//
    .FCLK         (FCLK),
    .IOADDR       (IOADDR[11:0]),		//
    .IOSEL        (IOSEL),
    .IOTRANS      (IOTRANS),
    .IOSIZE       (IOSIZE),
    .IOWRITE      (IOWRITE),
    .IOWDATA      (IOWDATA),

    // Outputs
    .IORDATA      (IORDATA),      //输出到外界

    .ECOREVNUM    (ECOREVNUM),// Engineering-change-order revision bits  引擎变化顺序 废除bit

    .PORTIN       (PORTIN),   // GPIO Interface inputs   gpio的输入接口（应该是输入才对吧）
    .PORTOUT      (PORTOUT),  // GPIO Interface outputs
    .PORTEN       (PORTEN),   //引脚使能信号
    .PORTFUNC     (PORTFUNC), // Alternate function control

    .GPIOINT      (GPIOINT),  // Interrupt outputs
    .COMBINT      (COMBINT)
  );

endmodule
