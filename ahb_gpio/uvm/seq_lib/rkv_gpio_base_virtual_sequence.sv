`ifndef RKV_GPIO_BASE_VIRTUAL_SEQUENCE_SV
`define RKV_GPIO_BASE_VIRTUAL_SEQUENCE_SV

class rkv_gpio_base_virtual_sequence extends uvm_sequence;

  rkv_gpio_config cfg;
  virtual rkv_gpio_if vif;
  rkv_gpio_rgm rgm;
  bit[31:0] wr_val, rd_val;
  uvm_status_e status;

  // element sequence declartion
  rkv_gpio_single_write_seq single_write;
  rkv_gpio_single_read_seq single_read;

  `uvm_object_utils(rkv_gpio_base_virtual_sequence)
  `uvm_declare_p_sequencer(rkv_gpio_virtual_sequencer)

  function new (string name = "rkv_gpio_base_virtual_sequence");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("body", "Entered...", UVM_LOW)
    // get cfg from p_sequencer
    cfg = p_sequencer.cfg;
    vif = cfg.vif;
    rgm = cfg.rgm;
    // TODO in sub-class
    wait_ready_for_stim();
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

  virtual function void compare_data(logic[31:0] val1, logic[31:0] val2, bit wildcmp = 0);  //数据比较 第三个参数wildcmp用来区分数据是进行算数全等（===）比较还是逻辑相等（==）比较
    cfg.seq_check_count++;
    if(wildcmp == 0) begin          //wildcmp为0
      if(val1 === val2)				//进行算数全等，数据中的x和z不考虑物理含义
        `uvm_info("CMPSUC", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2), UVM_LOW)
      else begin					
        cfg.seq_check_error++;
        `uvm_error("CMPERR", $sformatf("val1 'h%0x !== val2 'h%0x", val1, val2))
      end
    end
    else begin // 'x considered as wildcard icon  //如果wildcmp为1，那么数据中如果出现x或z，比较结果一定为x（未知）
      foreach(val1[i]) begin      
        if(val1[i] !== 1'bx && val2[i] !== 1'bx) begin  //对两个数据的每个bit为分别做检查，如果两个都不是x，才进行比较
          if(val1[i] !== val2[i]) begin
            cfg.seq_check_error++;
            `uvm_error("CMPERR", $sformatf("val1 'b%0b !== val2 'b%0b", val1, val2))  //按二进制显示（把每一位都显示出来）
            return;
          end
        end
      end
      `uvm_info("CMPSUC", $sformatf("val1 'b%0b === val2 'b%0b", val1, val2), UVM_LOW)
    end
  endfunction


  task wait_reset_signal_assertted();  //等待复位信号拉高
    @(posedge vif.rstn);
  endtask

  task wait_reset_signal_released();  //等待复位信号拉低（复位开始）
    @(negedge vif.rstn);
  endtask

  task wait_cycles(int n = 1, RKV_CLK_T t = CLK_HCLK);
    if(CLK_HCLK)
      repeat(n) @(posedge vif.clk);
    else
      repeat(n) @(posedge vif.fclk);
  endtask

  task wait_ready_for_stim();
    wait_reset_signal_released();  //复位信号拉低
    drive_portin_idle();           //把portin清零（准备接受新数据）
    wait_cycles(10);			   //等待10个周期（保险起见）
  endtask

  task drive_portin_idle();  //从外面传进来的数据是0；赋值给portin（相当于复位了）
    vif.drive_portin(0);
  endtask
  
    // task drive_portin(logic [15:0] bits);  //把传进来的数赋值给portin；
    //   portin <= bits;
    // endtask


  // GPIO REG ACCESS API （API就是封装起来的函数，避免重复造轮子）

  // bits[i] =  1'bx -> masked bit  //如果这一位上有x的话就不做修改，是0或1才会修改
  task set_portout_bits(logic [15:0] bits);  //设置portout的值
    logic [15:0] pout;     //默认值是x
    uvm_status_e status;
    //read_reg_with_addr(RKV_ROUTER_REG_ADDR_DATAOUT, pout);      //从DATAOUT寄存器中读取数据
    rgm.DATAOUT.read(status, pout);
    foreach(bits[i]) begin
      pout[i] = bits[i] === 1'bx ? pout[i] : bits[i];             //将传进来的数据的有效位对port进行覆盖
    end
    //write_reg_with_addr(RKV_ROUTER_REG_ADDR_DATAOUT, pout);
    rgm.DATAOUT.write(status, pout);                              //覆盖完成的数据再次写入DATAOUT寄存器
  endtask

  // id > 0 -> masked bit 
  task get_portin(output bit [15:0] bits, int id = -1);  //从寄存器读取引脚输入的数据  （id的作用是决定返回1位还是全部返回）
    bit bit_id = 0;                                    //暂存一下
    //read_reg_with_addr(RKV_ROUTER_REG_ADDR_DATA, bits);  //读取从引脚输入的数据 ，读出来的数就是bits
    rgm.DATA.read(status, bits);
    if(id >0) begin                   //id的作用是决定返回1位还是全部返回；如果id>0,只返回一位（只有那一位是有效的，其它位是0，无效;mask）
      bit_id = bits[id];									//先把bit[id](有效的那一位)提出来
      bits = 0;												//把bits清零，防止干扰
      bits[id] = bit_id;									//把有效值传回bits[id]
    end
  endtask

  // id > 0 -> masked bit 
  task set_intenset(input bit [15:0] bits, int id = -1);  //设置中断使能
    uvm_status_e status;
    bit[15:0] intenset;         
    if(id < 0) begin
      rgm.INTENSET.write(status, bits);    //如果id< 0，整个bits全部写入该寄存器 //这里耗时一个周期
    end
    else begin // single bit set          先读寄存器模型的期望值，再将期望值对应bit位设置好，随后将期望值写到寄存器模型中（这个过程不耗时，这也是为什么没有对硬件进行先读后写的原因）
      intenset = rgm.INTENSET.get();      //reg.get() 获取寄存器的期望值，并赋值给intenset
      intenset[id] = bits[id];				//  特定bit的引脚被设置成中断使能，
      rgm.INTENSET.set(intenset);			//	将准备好的使能数据写入到寄存器
      rgm.INTENSET.update(status);			//  更新，确保寄存器访问成功
    end
  endtask

  // id > 0 -> masked bit 
  task set_intenclr(input bit [15:0] bits); //写1就清除中断使能，写0没有影响；不用先读后写 
    uvm_status_e status;
    rgm.INTENCLR.write(status, bits);
  endtask

  task set_inttypeset(input bit [15:0] bits, int id = -1);  //设置第id位引脚的中断类型
    uvm_status_e status;
    bit[15:0] inttypeset;
    if(id < 0) begin
      rgm.INTTYPESET.write(status, bits);  //如果id< 0，整个bits全部写入该寄存器 
    end
    else begin // single bit set
      inttypeset = rgm.INTTYPESET.get();
      inttypeset[id] = bits[id];
      rgm.INTTYPESET.set(inttypeset);
      rgm.INTTYPESET.update(status);
    end
  endtask
t
  task set_intpolset(input bit [15:0] bits, int id = -1);  //设置中断极性
    uvm_status_e status;
    bit[15:0] intpolset;
    if(id < 0) begin
      rgm.INTPOLSET.write(status, bits);
    end
    else begin // single bit set
      intpolset = rgm.INTPOLSET.get();
      intpolset[id] = bits[id];
      rgm.INTPOLSET.set(intpolset);
      rgm.INTPOLSET.update(status);
    end
  endtask

  task set_inttypeclr(input bit [15:0] bits);  //写1就清除中断类型，写0没有影响；默认和set的id是一样的，不用先读后写
    uvm_status_e status;
    rgm.INTTYPECLR.write(status, bits);
  endtask

  task set_intpolclr(input bit [15:0] bits); //写1就清除中断极性，写0没有影响；不用先读后写
    uvm_status_e status;
    rgm.INTPOLCLR.write(status, bits);
  endtask

  task set_intclear(input bit [15:0] bits);//INTCLEAR寄存器，写1就清除中断状态，写0没有影响；不用先读后写
    uvm_status_e status;
    rgm.INTCLEAR.write(status, bits);
  endtask

  task read_reg_with_addr(bit [31:0] addr, output bit [31:0] data);  //有点代劳adaptor的功能
    `uvm_do_with(single_read, {addr == local::addr;})				 //single_read只是从总线读数据//按照地址从寄存器读数据
    data = single_read.data;
  endtask

  task write_reg_with_addr(bit [31:0] addr, bit [31:0] data);
    `uvm_do_with(single_write, {addr == local::addr; data == local::data;})
  endtask


endclass

`endif  
