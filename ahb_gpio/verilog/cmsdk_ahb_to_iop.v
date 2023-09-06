//-----------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from ARM Limited.
//
//            (C) COPYRIGHT 2012-2013 ARM Limited.
//                ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from ARM Limited.
//
//      SVN Information
//
//      Checked In          : $Date: 2012-08-02 16:26:56 +0100 (Thu, 02 Aug 2012) $
//
//      Revision            : $Revision: 217500 $
//
//      Release Information : Cortex-M System Design Kit-r1p0-00rel0
//
//-----------------------------------------------------------------------------
//
// Simple AHB to IOP Bridge (for use with the IOP GPIO to make an AHB GPIO).
//
//-----------------------------------------------------------------------------

module cmsdk_ahb_to_iop   //ahb到ioport的桥接端口
// ----------------------------------------------------------------------------
// Port Definitions  
// ----------------------------------------------------------------------------
  (// AHB Inputs
   input  wire                 HCLK,      // system bus clock
   input  wire                 HRESETn,   // system bus reset
   input  wire                 HSEL,      // AHB peripheral select
   input  wire                 HREADY,    // AHB ready input
   input  wire  [1:0]          HTRANS,    // AHB transfer type
   input  wire  [2:0]          HSIZE,     // AHB hsize  
   input  wire                 HWRITE,    // AHB hwrite
   input  wire [11:0]          HADDR,     // AHB address bus
   input  wire [31:0]          HWDATA,    // AHB write data bus

   // IOP Inputs
   input wire [31:0]           IORDATA,    // I/0 read data bus

   // AHB Outputs //对外界的输出信号线
   output wire                 HREADYOUT, // AHB ready output to S->M mux
   output wire                 HRESP,     // AHB response
   output wire [31:0]          HRDATA,

   // IOP Outputs  //对ioport的输出信号线6跟
   output reg                  IOSEL,      // Decode for peripheral
   output reg  [11:0]          IOADDR,     // I/O transfer address
   output reg                  IOWRITE,    // I/O transfer direction  传输方向（难道还有数据进来吗）
   output reg  [1:0]           IOSIZE,     // I/O transfer size  位宽
   output reg                  IOTRANS,    // I/O transaction  
   output wire [31:0]          IOWDATA);   // I/O write data bus  给ioport写数据（应该被覆盖了）

  // ----------------------------------------------------------
  // Read/write control logic  读写控制逻辑
  // ----------------------------------------------------------

  // registered HSEL, update only if selected to reduce toggling
  always @(posedge HCLK or negedge HRESETn)
  begin
    if (~HRESETn)
      IOSEL <= 1'b0;
    else
      IOSEL <= HSEL & HREADY;
  end

  // registered address, update only if selected to reduce toggling
  always @(posedge HCLK or negedge HRESETn)
  begin
    if (~HRESETn)       
      IOADDR <= {12{1'b0}};
    else
      IOADDR <= HADDR[11:0];  //地址线等于总线写入的地址
  end

  // Data phase write control
  always @(posedge HCLK or negedge HRESETn)
  begin
    if (~HRESETn)
      IOWRITE <= 1'b0;
    else
      IOWRITE <= HWRITE;   //读写操作等于总线的读写操作
  end

  // registered hsize, update only if selected to reduce toggling
  always @(posedge HCLK or negedge HRESETn)
  begin
    if (~HRESETn)
      IOSIZE <= {2{1'b0}};
    else
      IOSIZE <= HSIZE[1:0];  //数据位宽等于总线的数据位宽
  end

  // registered HTRANS, update only if selected to reduce toggling
  always @(posedge HCLK or negedge HRESETn)
  begin
    if (~HRESETn)
      IOTRANS <= 1'b0;
    else
      IOTRANS <= HTRANS[1];  //传输类型等于总线的传输类型
  end

  assign IOWDATA   = HWDATA;  //io写数据等于ahb总线写进来的数
  assign HRDATA    = IORDATA;  //ahb总线读数据等于io读数据
  assign HREADYOUT = 1'b1;	//默认传输成功
  assign HRESP     = 1'b0;  //默认返回值是0

endmodule


//