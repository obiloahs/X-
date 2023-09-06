`ifndef RKV_GPIO_MASKED_ACCESS_VIRT_SEQ_SV
`define RKV_GPIO_MASKED_ACCESS_VIRT_SEQ_SV


class rkv_gpio_masked_access_virt_seq extends rkv_gpio_base_virtual_sequence;
  `uvm_object_utils(rkv_gpio_masked_access_virt_seq)

  function new (string name = "rkv_gpio_masked_access_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    repeat(10) begin
      set_and_check_masked_access(0); // via address 通过地址访问
      set_and_check_masked_access(1); // via RGM	通过寄存器模型访问
    end
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

  task set_and_check_masked_access(bit via_rgm = 0);
    logic [15:0] portout_reg_write, portout_expected;  //前者：potrout端口寄存器写入值  后者：portout端口期望值（根据mask自己计算）
    logic [15:0] portout_port_mon, portin_port_drv;		//前者：portout端口总线监测值  后者：portin端口总线驱动值
    logic [15:0] maskbyte_reg_write, maskbyte_reg_read;	//前者：MASKLOWBYTE寄存器（0x0400）和MASKHIGHBYTE寄存器（0x0800）写入值（即写入portout的新数据）
														//后者：MASKLOWBYTE寄存器（0x0400）和MASKHIGHBYTE寄存器（0x0800）读出值（即写入portout的新数据）
    bit [15:0] mask;									//遮盖值（为0遮盖，为1需要修改）
    bit [15:0] addr_masklowbyte, addr_maskhighbyte; 	//低8位寄存器存储地址  高8位寄存器存储地址（根据mask自己计算）
    uvm_status_e status;
    std::randomize(portout_reg_write, mask, maskbyte_reg_write, portin_port_drv);

    // check PORTOUT 											这里就是检查pirtout端口能不能通过寄存器DATAOUT进行配置
    set_portout_bits(portout_reg_write);                       //先从寄存器DATAOUT中读出来，再把portout_reg_write写进去（是1就写进去，x就不变）
    wait_cycles(2); // one-cycle from io-bridge to portout 		//从HCLK到FCKK需要2个hclk时钟周期（1个fclk时钟周期）
    portout_port_mon = vif.portout;								//从总线读portout端口
    compare_data(portout_reg_write, portout_port_mon);			//进行比较

    // calculate addr													计算地址（基地址+mask的值*2）目的是存储数据
    addr_masklowbyte = RKV_ROUTER_REG_ADDR_MAS KLOWBYTE + (mask[7:0] << 2);
    addr_maskhighbyte = RKV_ROUTER_REG_ADDR_MASKHIGHBYTE + (mask[15:8] << 2);

    // set MASKLOWBYTE and MASKHIGHBYTE					设置要写入的新数据（分为高8位和底8位），设置好以后写到对应寄存器（高位寄存器和低位寄存器）
    if(!via_rgm) begin													//通过地址写入
      write_reg_with_addr(addr_masklowbyte,  maskbyte_reg_write & 16'h00FF); //向高8位寄存器写随机出来的
      write_reg_with_addr(addr_maskhighbyte, maskbyte_reg_write & 16'hFF00);
    end
    else begin															//通过寄存器模型写入
      rgm.MASKLOWBYTE[mask[7:0]].write(status, maskbyte_reg_write & 16'h00FF);
      rgm.MASKHIGHBYTE[mask[15:8]].write(status, maskbyte_reg_write & 16'hFF00);
    end

    // check PORTOUT with/without MASKED-BYTE
    wait_cycles(2); 
    foreach(portout_expected[i]) portout_expected[i] = mask[i] ? maskbyte_reg_write[i] : portout_reg_write[i]; //期望值：如果mask[i]是1，那么portout里的portout_reg_write[i]就会被maskbyte_reg_write[i]替换
    compare_data(vif.portout, portout_expected);	//总线监测到的portout端口值和期望值进行比较
    
    // TODO:: check if design is consistent with the check intention below
    // check read addr value from MASKED-BYTE
	/*，编程者并不需要显式地对portin进行mask操作，编程者要做的就是参照Figure3-7和Figure3-8去计算访问地址，读回来的值就是所期望得到的*/
    vif.portin = portin_port_drv;								//通过总线向portin做驱动
    wait_cycles(4, CLK_FCLK);									//等几个周期，用于异步信号采集同步
    if(!via_rgm) begin
      read_reg_with_addr(addr_masklowbyte,  maskbyte_reg_read);				//读出低8位地址的数据
      compare_data(maskbyte_reg_read, portin_port_drv & mask & 16'h00FF);	//驱动数据的低8位和mask做与操作，读回来的数据应该只有遮盖bit有效
      read_reg_with_addr(addr_maskhighbyte,  maskbyte_reg_read);
      compare_data(maskbyte_reg_read, portin_port_drv & mask & 16'hFF00); //后者--“对直接传递给portin接口的值进行mask操作”这是用于生成期望吧，因为你这是验证嘛
    end
    else begin
      rgm.MASKLOWBYTE[mask[7:0]].read(status, maskbyte_reg_read);  
      compare_data(maskbyte_reg_read, portin_port_drv & mask & 16'h00FF);
      rgm.MASKHIGHBYTE[mask[15:8]].read(status, maskbyte_reg_read);
      compare_data(maskbyte_reg_read, portin_port_drv & mask & 16'hFF00);
    end
  endtask

endclass


`endif 
