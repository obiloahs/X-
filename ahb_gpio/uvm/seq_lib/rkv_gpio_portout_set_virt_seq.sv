`ifndef RKV_GPIO_PORTOUT_SET_VIRT_SEQ_SV
`define RKV_GPIO_PORTOUT_SET_VIRT_SEQ_SV


class rkv_gpio_portout_set_virt_seq extends rkv_gpio_base_virtual_sequence;
  `uvm_object_utils(rkv_gpio_portout_set_virt_seq)

  function new (string name = "rkv_gpio_portout_set_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] addr, data;
    bit [3:0] pin_num, pout_num;            //portin和portout的各个bit位
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    repeat(10) begin
      std::randomize(pin_num, pout_num);  //对每一位引脚进行遍历（一次只能改变一位）
      set_and_check_portin(pin_num);		//对portin ：总线驱动，寄存器读
      set_and_check_portout(pout_num);		//对portout：寄存器驱动，总线读
    end
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

//从总线（vif）写进去，然后从DATA寄存器那里读取//所以等了三拍
  task set_and_check_portin(bit[3:0] id);                    //对portin先drive写后read，最后进行比较  //drive和read都是异步驱动，和系统时钟在后续会用两个周期来同步
    bit [15:0] pin_dr, pin_rd;								 //这里用dr，是因为portin的数据是从interface层面做驱动，没有其他模块进行写操作，比较直接				 
    bit bit_pattern [$] = {1, 0, 1};            			 //这里考虑coverage的部分，对应bit的翻转              
    foreach(bit_pattern[i]) begin
      pin_dr[id] = bit_pattern[i];							 //驱动portin[id]3次，顺序是1-0-1//drive的时候只对某个bit位进行驱动，其余bit为0；读的时候也只读出该有效比特位，其余bit为0
      vif.drive_portin(pin_dr);								 //给portin做drive，传进来的pin_dr赋值给portin               set
      wait_cycles(3); // two-cycles for sync				 //预留3拍子，因为从if驱动，再从寄存器读出来，至少需要两拍
      get_portin(pin_rd, id);								 //读取portin的数值，赋值给pin_rd（portin的第id位数有效，其它比特位都是0） //从寄存器DATA读
      compare_data(pin_dr, pin_rd);							 //portin写入的值和读出的值进行比较
    end
  endtask

//从DATAOUT寄存器写进去（其实从DATA寄存器写也可以），然后从总线（vif）读出来//等了2排
  task set_and_check_portout(bit[3:0] id);					 //对portout先write写后monitor，最后进行比较（没有read，因为不需要按有效位读，全读过来，不需要mask）
    logic [15:0] pout_wr, pout_mo; //pout_wr默认值是x，这里用wr，是因为portout的数据是内部模块写进去的//这里用mo，是因为我们默认寄存器的读写应该是没问题的，在寄存器这里配置后直接去检测对应端口（portout）的值
    bit bit_pattern [$] = {0, 1, 0};
    foreach(bit_pattern[i]) begin								 
      pout_wr[id] = bit_pattern[i];							 //write的时候只对某个bit位进行写入，其余bit为x；这样在执行下面set_portout_bits(pout_wr)	函数的时候，只有有效位被写入portout					
      set_portout_bits(pout_wr);							 //对poutout进行设置（先读出来，把我们想set的值赋值给它，再写进去）
      wait_cycles(2); // one-cycle from io-bridge to portout //
      pout_mo = vif.portout;								 //写完之后，在总系进行采样，得到采样值
      compare_data(pout_wr, pout_mo, .wildcmp(1));			 //将写入的数据pout_wr和采样到的数据pout_mo进行对比
    end
  endtask

endclass


`endif 
