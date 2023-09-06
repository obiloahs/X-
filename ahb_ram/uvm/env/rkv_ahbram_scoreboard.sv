`ifndef RKV_AHBRAM_SCOREBOARD_SV
`define RKV_AHBRAM_SCOREBOARD_SV

class rkv_ahbram_scoreboard extends rkv_ahbram_subscriber;

  // events of scoreboard
  bit [31:0] mem [int unsigned];  //利用一个关联数据存储数据

  // typedef enum {CHECK_LOADCOUNTER} check_type_e;
  `uvm_component_utils(rkv_ahbram_scoreboard)

  function new (string name = "rkv_ahbram_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    do_data_check();
  endtask

  virtual function void write(lvc_ahb_transaction tr);  //monitor的run_phase将会调用这个函数，从而将数据通过TLM端口传进来
    if(is_addr_valid(tr.addr)) begin
      case(tr.xact_type)
        WRITE : store_data_with_hburst(tr);  //通过hburst的不同存储数据，将写入的数据存入mem中
        READ  : check_data_with_hburst(tr);  //通过hburst的不同来比较数据（读回来的数据不需要存储，只需要和之前men中改地址的数据进行比较就行了）
      endcase
    end
  endfunction

  task do_listen_events();
  endtask

  virtual task do_data_check();  //没用
  endtask

  function bit is_addr_valid(bit [31:0] addr);  //先判断地址合不合法，合法返回1，不合法返回0
    if(addr >= cfg.addr_start && addr <= cfg.addr_end)  
      return 1; 
  endfunction

  function void store_data_with_hburst(lvc_ahb_transaction tr);  //通过hburst的不同存储数据，将写入的数据存入mem中
    // TODO implementation in child class
    case(tr.burst_type)
      SINGLE: begin   
                store_data_with_hsize(tr, 0); //burst_type只支持SINGLE模式，此时通过hsize的不同存储数据
              end
      INCR  : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP4 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR4 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP8 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR8 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP16: begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR16: begin `uvm_error("TYPEERR", "burst type not supported yet") end
      default: begin `uvm_error("TYPEERR", "burst type not defined") end
    endcase
  endfunction

  function bit check_data_with_hburst(lvc_ahb_transaction tr);  //通过hburst的不同来比较数据
    // TODO implementation in child class
    case(tr.burst_type)
      SINGLE: begin 
                check_data_with_hburst = (check_data_with_hsize(tr, 0));//通过hsize的不同进行数据比较，比较结果成功返回1，失败返回0
              end
      INCR  : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP4 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR4 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP8 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR8 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP16: begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR16: begin `uvm_error("TYPEERR", "burst type not supported yet") end
      default: begin `uvm_error("TYPEERR", "burst type not defined") end
    endcase
    if(check_data_with_hburst)
      `uvm_info("DATACHK", $sformatf("ahbram[%0x] hburst[%s] is as expected", tr.addr, tr.burst_type), UVM_HIGH)
    else
      `uvm_error("DATACHK", $sformatf("ahbram[%0x] hburst[%s] is NOT as expected", tr.addr, tr.burst_type))
  endfunction

  function void store_data_with_hsize(lvc_ahb_transaction tr, int beat);  //通过hsize的不同存储数据，hsize不同的话，写入数据的有效位需要master端抽取
    case(tr.burst_size)  //
      BURST_SIZE_8BIT   : mem[{tr.addr[31:2],2'b00}] = extract_current_beat_mem_data(tr, beat); //·
      BURST_SIZE_16BIT  : mem[{tr.addr[31:2],2'b00}] = extract_current_beat_mem_data(tr, beat);
      BURST_SIZE_32BIT  : mem[{tr.addr[31:2],2'b00}] = extract_current_beat_mem_data(tr, beat);
      BURST_SIZE_64BIT  : begin `uvm_error("TYPEERR", "burst size not supported") end  
      default : begin `uvm_error("TYPEERR", "burst size not supported") end
    endcase
  endfunction

  function bit check_data_with_hsize(lvc_ahb_transaction tr, int beat);  //如果是读操作，将从ram（dut）读出的数据和mem中该地址的数据进行比较
    bit[31:0] tdata = extract_valid_data(tr.data[beat], tr.addr, tr.burst_size);  //根据地址抽取dut读出数据的有效位
    bit[31:0] mdata = extract_valid_data(mem[{tr.addr[31:2],2'b00}],  tr.addr, tr.burst_size);//根据地址抽取mem中数据的有效位
    check_data_with_hsize = tdata == mdata ? 1 : 0; //ram数据和mem数据的有效位进行比较，成功输出1，失败输出0
    cfg.scb_check_count++;
    if(check_data_with_hsize)
      `uvm_info("DATACHK", $sformatf("ahbram[%0x] data expected 'h%0x = actual 'h%0x", tr.addr, mdata, tdata), UVM_HIGH)
    else begin
      cfg.scb_check_error++;
      `uvm_error("DATACHK", $sformatf("ahbram[%0x] data expected 'h%0x != actual 'h%0x", tr.addr, mdata, tdata))
    end
  endfunction

  function bit [31:0] extract_current_beat_mem_data(lvc_ahb_transaction tr, int beat);  //根据数据位宽抽取抽取当前数据的有效值，并将有效值存入mem中该地址的数据的相应位
    bit [31:0] mdata = mem[{tr.addr[31:2],2'b00}];  //
    bit [31:0] tdata = tr.data[beat];  //
    case(tr.burst_size) 
      BURST_SIZE_8BIT   : mdata[(tr.addr[1:0]*8 + 7) -:  8] = tdata >> (8*tr.addr[1:0]);//写入数据是8bit，提取写入地址的后两位提取写入数据有效位，然后赋值给mem中（覆盖有效位）
	  BURST_SIZE_16BIT  : mdata[(tr.addr[1]*16 + 15) -: 16] = tdata >> (16*tr.addr[1]);//写入数据是16bit，提取写入地址的后两位提取写入数据有效位，然后赋值给mem中（覆盖有效位）
      BURST_SIZE_32BIT  : mdata = tdata;                                                //写入数据是32bit，全部有效，直接写入
      BURST_SIZE_64BIT  : begin `uvm_error("TYPEERR", "burst size not supported") end
      default : begin `uvm_error("TYPEERR", "burst size not supported") end
    endcase
    return mdata; //返回更新（有效值已被写入）的mdata；最终返回给mem中

endclass

`endif 





/* function bit [31:0] extract_valid_data([`LVC_AHB_MAX_DATA_WIDTH - 1:0] data  //定义在lvc_ahb_types中 
										,[`LVC_AHB_MAX_ADDR_WIDTH - 1 : 0] addr
                                        ,burst_size_enum bsize);
										
    case(bsize)
      BURST_SIZE_8BIT   : return (data >> (8*addr[1:0])) & 8'hFF;    //按照地址最后两位进行右移操作，将有效位移到数据低8位
      BURST_SIZE_16BIT  : return (data >> (16*addr[1]) ) & 16'hFFFF; //按照地址最后两位进行右移操作，将有效位移到数据低16位
      BURST_SIZE_32BIT  : return data & 32'hFFFF_FFFF;					//数据全部有效
      BURST_SIZE_64BIT  : begin `uvm_error("TYPEERR", "burst size not supported") end
      default : begin `uvm_error("TYPEERR", "burst size not supported") end
    endcase
  endfunction */