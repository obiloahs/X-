`ifndef LVC_AHB_MASTER_DRIVER_SV
`define LVC_AHB_MASTER_DRIVER_SV

class lvc_ahb_master_driver extends lvc_ahb_driver;

  `uvm_component_utils(lvc_ahb_master_driver)

  function new(string name = "lvc_ahb_master_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask

  virtual task drive_transfer(REQ t);
    // TODO implementation in child class
    case(t.burst_type)
      SINGLE: begin do_atomic_trans(t); end
      INCR  : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP4 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR4 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP8 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR8 : begin `uvm_error("TYPEERR", "burst type not supported yet") end
      WRAP16: begin `uvm_error("TYPEERR", "burst type not supported yet") end
      INCR16: begin `uvm_error("TYPEERR", "burst type not supported yet") end
      default: begin `uvm_error("TYPEERR", "burst type not defined") end
    endcase
  endtask

  virtual task do_atomic_trans(REQ t);
    case(t.xact_type)
      READ      : do_read(t);
      WRITE     : do_write(t);
      IDLE_XACT : begin `uvm_error("TYPEERR", "trans type not supported yet") end
      default: begin `uvm_error("TYPEERR", "trans type not defined") end
    endcase
  endtask

  virtual task wait_for_bus_grant();
    @(vif.cb_mst iff vif.cb_mst.hgrant === 1'b1);
  endtask

  virtual task do_write(REQ t);
    do_init_write(t);
    do_proc_write(t);
  endtask

  virtual task do_read(REQ t);
    do_init_read(t);
    do_proc_read(t);
  endtask

  virtual task do_init_write(REQ t);
    wait_for_bus_grant();  //63-68行表示地址和控制周期，第一排的htrans是NSEQ，不连续的事务（NONSEQUENTIAL transaction）
    vif.cb_mst.htrans <= NSEQ;
    vif.cb_mst.haddr  <= t.addr;
    vif.cb_mst.hburst <= t.burst_type;
    vif.cb_mst.hsize  <= t.burst_size;
    vif.cb_mst.hwrite <= 1'b1;
    @(vif.cb_mst);
    if(t.burst_type == SINGLE) begin  /*这里表示数据周期，如果传输类型是SINGLE类型的话，所有信号线清零；
								（如果不是SINGLE，除了数据线hwdatahe hrdata需要清零外，其它的信号线都按照协议变化（比如地址和控制线会变成下一拍的））*/
      _do_drive_idle();
    end
    vif.cb_mst.hwdata <= t.data[0]; /*第二拍 不管ready信号是不是啊拉高了，数据都发到总线上去了
										（读操作只能等ready信号拉高才能将总线数据读出来//ready拉低的话从端不给数据，读啥？）*/
    // check ready with delay in current cycle
    forever begin
      @(negedge vif.hclk); /*节拍中间下降沿观察ready是否拉高（这一排没有用clock block，
						我觉得可以变成posedge vif.cb_mst.clk（或者是@ vif.cb_mst） 
						因为这两个时间点采样到的数据是一样的）*/
      if(vif.hready === 1'b1) begin   
        break;  //如果拉高，就跳出forever
      end
      else
        @(vif.cb_mst);  //如果没有拉高，再等一拍，看下一拍中间hclk中间下降沿ready信号是否拉高
    end

    // update current trans status
    t.trans_type = NSEQ;
    t.current_data_beat_num = 0; // start beat from 0 to make consistence with data array index
    t.all_beat_response[t.current_data_beat_num] = response_type_enum'(vif.hresp);/*这里的vif.hresp，没有用blocking块，
																				因为resp是cb_mst的采样信号（input），
																				此时此刻所处的时间点是数据传输阶段的中间（时钟下降沿），
																				而时钟块的时间点是posedge clk，所以不能用；
																				如果上面103行用的是@ vit.cb_mst,
																				那在这行就可以用vif.cb_mst.hresp*/
  endtask

  virtual task do_init_read(REQ t);
    wait_for_bus_grant();
    vif.cb_mst.htrans <= NSEQ;
    vif.cb_mst.haddr  <= t.addr;
    vif.cb_mst.hburst <= t.burst_type;
    vif.cb_mst.hsize  <= t.burst_size;
    vif.cb_mst.hwrite <= 1'b0;
    @(vif.cb_mst);
    if(t.burst_type == SINGLE) begin
      _do_drive_idle();
    end
    // check ready with delay in current cycle
    forever begin
      @(negedge vif.hclk);
      if(vif.hready === 1'b1) begin
        break; 
      end
      else
        @(vif.cb_mst); 
    end
    t.data = new[t.current_data_beat_num+1](t.data);
    t.data[0] = vif.hrdata;
    
    // update current trans status
    t.trans_type = NSEQ;
    t.current_data_beat_num = 0; // start beat from 0 to make consistence with data array index
    t.all_beat_response[t.current_data_beat_num] = response_type_enum'(vif.hresp);
  endtask

  virtual task do_proc_write(REQ t);
    // TODO implement for SEQ operations of other BURST types
    // do_init_idle(t);
  endtask

  virtual task do_proc_read(REQ t);
    // TODO implement for SEQ operations of other BURST types
    // do_init_idle(t);
  endtask

  virtual protected task do_init_idle(REQ t);
    @(vif.cb_mst);
    _do_drive_idle();
  endtask

  virtual protected task _do_drive_idle();
    vif.cb_mst.haddr     <= 0;
    vif.cb_mst.hburst    <= 0;
    vif.cb_mst.hbusreq   <= 0;
    vif.cb_mst.hlock     <= 0;
    vif.cb_mst.hprot     <= 0;
    vif.cb_mst.hsize     <= 0;
    vif.cb_mst.htrans    <= 0;
    vif.cb_mst.hwdata    <= 0;
    vif.cb_mst.hwrite    <= 0;
  endtask

  virtual protected task reset_listener();
    `uvm_info(get_type_name(), "reset_listener ...", UVM_HIGH)
    fork
      forever begin
        @(negedge vif.hresetn); // ASYNC reset
        _do_drive_idle();
      end
    join_none
  endtask

endclass


`endif // LVC_AHB_MASTER_DRIVER_SV
