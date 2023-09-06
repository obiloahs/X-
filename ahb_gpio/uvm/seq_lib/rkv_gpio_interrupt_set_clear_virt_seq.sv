`ifndef RKV_GPIO_INTERRUPT_SET_CLEAR_VIRT_SEQ_SV
`define RKV_GPIO_INTERRUPT_SET_CLEAR_VIRT_SEQ_SV

class rkv_gpio_interrupt_set_clear_virt_seq extends rkv_gpio_base_virtual_sequence;
  `uvm_object_utils(rkv_gpio_interrupt_set_clear_virt_seq)

  function new (string name = "rkv_gpio_interrupt_set_clear_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] addr, data;
    bit [3:0] int_num;
    bit [15:0] set_bits;                      //要传入寄存器的值
    bit bit_pattern [$] = {0, 1};  				//两种模式，有一个0-1的跳变过程
    RKV_INT_POL_T intpol; 
    RKV_INT_TYPE_T inttype;
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    for(int i = 0; i < 16; i++) begin        		 //一个bit一个bit位进行测试
      foreach(bit_pattern [j]) begin     			//遍历每个bit的中断类型	{inttype,intpol} = {0,0 低电平}/{0,1高电平}/{1,0下降沿}/{1,1上升沿}  		 
        foreach(bit_pattern [k]) begin
		
		
          set_bits = bit_pattern[j] << i;			 //移位到对应的bit位,这里j是设置第一个参数inttype
          set_inttypeset(set_bits, i);				 //第i位设置成0-1，
          inttype = RKV_INT_TYPE_T'(bit_pattern[j]); //做了转化，这里把inttype确定下来
		  
		  
          set_bits = bit_pattern[k] << i;            //这里k是设置第二个参数intpol
          set_intpolset(set_bits, i);
          intpol = RKV_INT_POL_T'(bit_pattern[k]);
		  
		  
          int_set_and_check(i, inttype, intpol);	  
        end
      end
    end
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

  task int_set_and_check(int id, RKV_INT_TYPE_T inttype, RKV_INT_POL_T intpol);
    // TODO 
    bit [15:0] set_bits; 
    set_bits = 1'b1 << id;     				//在这里设置对应的引脚为1
    // check interrupt bit is inactive       初始状态下检查GPIOINT[id]的值
    check_int_via_intf(id, 0); 				//从从接口总线读gpioint的值，和0进行比较（初始状态下gpioint的该bit位应该不生效为0）
    check_int_via_reg(id, 0);  				//从INTSTATUS0x0038寄存器读值（这个寄存器就是反应GPIOINT端口的值），和0进行比较
    case({inttype, intpol})					//第id个引脚当前的中断模式分类		
      {ACTIVE_LEVEL, ACTIVE_LOW} : begin 	//{0,0} 低电平（当前这根引脚的中断模式是低电平有效，测试的时候就先把他拉高，10个周期后再拉低，看中断是否生效）
        vif.portin[id] <= 1'b1;					//先把portin[id]拉高，
        wait_cycles(10, CLK_FCLK);					//等10个FCLK的周期
        vif.portin[id] <= 1'b0;							//再把portin[id]拉低
      end
      {ACTIVE_LEVEL, ACTIVE_HIGH} : begin 	//{0,1} 高电平
        vif.portin[id] <= 1'b0;					//先把portin[id]拉低
        wait_cycles(10, CLK_FCLK);					//等10个FCLK的周期
        vif.portin[id] <= 1'b1;							//再把portin[id]拉高
      end
      {ACTIVE_EDGE, ACTIVE_LOW} : begin 	//{1,0} 下降沿
        vif.portin[id] <= 1'b1;					//先把portin[id]拉高，
        wait_cycles(10, CLK_FCLK);					//等10个FCLK的周期
        vif.portin[id] <= 1'b0;							//再把portin[id]拉低
      end
      {ACTIVE_EDGE, ACTIVE_HIGH} : begin 	//{1,0} 上升沿
        vif.portin[id] <= 1'b0;					//再把portin[id]拉低
        wait_cycles(10, CLK_FCLK);					//等10个FCLK的周期
        vif.portin[id] <= 1'b1;							//再把portin[id]拉高
      end
    endcase

    // check interrupt bit is active after PORTIN changes with INTTYPE
	//把第id个引脚的中断类型确定下来以后，再把它的中断使能信号拉高
    // & INTPOL 
    set_intenset(set_bits, id);			//拉高该id的中断使能信号
    wait_cycles(4, CLK_FCLK);			//这里要等是因为GPIOINT的是在fclk上升沿被驱动，为了准确采样得到准确值，
    check_int_via_intf(id, 1);			//通过总线接口检查GPIOINT[id]是否拉高
    check_int_via_reg(id, 1);			//通过寄存器INTSTATUS检查他的第id位是否拉高

    // check interrupt bit is inactive after INTENCLR & INTCLEAR is set
    set_intenclr(set_bits); 			//使能关了
    set_intclear(set_bits);				//INTESTATUS[id]拉低   使能和状态寄存器都关了之后int
    wait_cycles(4, CLK_FCLK);
    check_int_via_intf(id, 0);			//总线读GPININT[id]检查是否拉低
    check_int_via_reg(id, 0);			//寄存器模型读INTESTATUS[id]看是否拉低

    set_inttypeclr(set_bits);			//这俩寄存器也拉低
    set_intpolclr(set_bits);
  endtask

  task check_int_via_intf(int id, bit val);  
    compare_data(vif.gpioint[id], val);			//总线那里监测gpioin，检测到的数据和val进行比较
  endtask

  task check_int_via_reg(int id, bit val);   	//通过寄存器模型读INTSTATUS的值（这里寄存器的值就是GPIOINT端口的值）
    uvm_status_e status;
    bit [15:0] gpioint;
    rgm.INTSTATUS.read(status, gpioint);       //从寄存器INTSTATUS读回来的值赋值给gpioint
    compare_data(gpioint[id], val);				//进行比较
  endtask


endclass


`endif 
