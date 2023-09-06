`ifndef RKV_AHBRAM_RESET_W2R_VIRT_SEQ_SV
`define RKV_AHBRAM_RESET_W2R_VIRT_SEQ_SV


class rkv_ahbram_reset_w2r_virt_seq extends rkv_ahbram_base_virtual_sequence;
  `uvm_object_utils(rkv_ahbram_reset_w2r_virt_seq)

  function new (string name = "rkv_ahbram_reset_w2r_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] addr, data;
    bit [31:0] addr_q[$];  //声明地址队列，将所有addr都记录下来
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    // normal write -> read check 正常的读写访问检查
    for(int i=0; i<10; i++) begin
      std::randomize(addr) with {addr[1:0] == 0; addr inside {['h1000:'h1FFF]};};
      std::randomize(wr_val) with {wr_val == (i << 4) + i;};
      addr_q.push_back(addr);  //将地址存入队列尾
      data = wr_val;
      `uvm_do_with(single_write, {addr == local::addr; data == local::data;})
      //`uvm_do_with(single_write, {addr == local::addr; data == 'hff;})
      `uvm_do_with(single_read, {addr == local::addr; })
      rd_val = single_read.data;
      compare_data(wr_val, rd_val);
    end

    // trigger reset
    vif.assert_reset(10);  //调用if里面的复位信号，理论上讲reset后的dut信号都是x（实际上dut的逻辑没有reset参与，说明dut功能不完善）

    // read check after reset
    do begin  //调用一个reset后 再进行一次读操作
       //地址值再从队列头中拿出来
      `uvm_do_with(single_read, {addr == local::addr; }) //再做一次读操作
      rd_val = single_read.data; 
      if(cfg.init_logic === 1'b0) //定义的init_logic（在cfg中）用来模拟mem的reset后的行为（当init_logic为0，mem全0，当init_logic为x，mem全x//本项目初始为全x）
        compare_data(32'h0, rd_val);
      else if(cfg.init_logic === 1'bx) //注意这里用的是三个等号（全等），x也可以比较  
        compare_data(32'hx, rd_val);
      else
        `uvm_error("TYPEERR", "type is not recognized")
    end while(addr_q.size() > 0);

    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask
 

`endif 
//先做一个w2r的检查，然后将系统复位，（复位后mem的值全为x，理想中的dut值也应该复位为x）；
//做一次read的操作，最后作比较，结果显示比较错误，查看波形和dut设计代码得知dutreset后没有把data信号复位
