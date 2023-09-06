`ifndef LVC_AHB_MONITOR_SV
`define LVC_AHB_MONITOR_SV

class lvc_ahb_monitor extends uvm_monitor;
  lvc_ahb_agent_configuration cfg;
  virtual lvc_ahb_if vif;
  uvm_analysis_port #(lvc_ahb_transaction) item_observed_port;

  `uvm_component_utils(lvc_ahb_monitor)

  function new(string name = "lvc_ahb_monitor", uvm_component parent = null);
    super.new(name, parent);
    item_observed_port = new("item_observed_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork  //为什么用fork join_none
      monitor_transactions();
    join_none
  endtask

  task monitor_transactions();
    lvc_ahb_transaction t;
    forever begin //为什么用forever
      collect_transfer(t);  //采样
      item_observed_port.write(t); //广播出去
    end
  endtask

  task collect_transfer(output lvc_ahb_transaction t);
    // collect transfer from interface
    t = lvc_ahb_transaction::type_id::create("t");//先创建
    @(vif.cb_mon iff vif.cb_mon.htrans == NSEQ);//合适的时间点采样  等NSEQ的标志（在第一拍的时候）；记录以下数据
    t.trans_type = trans_type_enum'(vif.cb_mon.htrans);//当前节拍的传输类型（NSEQ）
    t.xact_type = xact_type_enum'(vif.cb_mon.hwrite);//当前是WRITE还是READ
    t.burst_type = burst_type_enum'(vif.cb_mon.hburst);//当前的传输类型（SINGLE）
    t.burst_size = burst_size_enum'(vif.cb_mon.hsize);//当前数据的size
    t.addr = vif.cb_mon.haddr;//当前的地址
    forever begin //这里用forever是为了等一个ready信号拉高哈哈，并且等trans_type为IDLE时就不采样了
      monitor_valid_data(t);
      if(t.trans_type == IDLE)//第二拍 变成IDLE后跳出去，准备进入下一个数据传输 
        break;
    end
    t.response_type = t.all_beat_response[t.current_data_beat_num];
  endtask

  task monitor_valid_data(lvc_ahb_transaction t);
    @(vif.cb_mon iff vif.cb_mon.hready);//第二拍的时候，先看ready是不是为高，如果是就做以下操作
    t.increase_data();//给data扩容
    t.current_data_beat_num = t.data.size() - 1;//data计数的值（当前是第几个data）  本项目中只能是0
    // get draft data from bus   //从总线拿数据草稿（没有根据地址选）
    t.data[t.current_data_beat_num] = t.xact_type == WRITE ? vif.cb_mon.hwdata : vif.cb_mon.hrdata;//从总线拿数据（先判断当前是读还是写）
    // NOTE:: alinged not to extract the valid data after shifted 约定monitor不做偏移
    // extract_vali_data(t.data[t.current_data_beat_num], t.addr, t.burst_size);
    t.all_beat_response[t.current_data_beat_num] = response_type_enum'(vif.cb_mon.hresp);//记录当前data的rsp信号
    t.trans_type = trans_type_enum'(vif.cb_mon.htrans);//记录当前节拍的传输类型，可能由NSEQ变成了IDLE（本项目中肯定是这样）
  endtask

endclass


`endif // LVC_AHB_MONITOR_SV
