`ifndef LVC_AHB_TRANSACTION_SV
`define LVC_AHB_TRANSACTION_SV


class lvc_ahb_transaction extends uvm_sequence_item;

  // wdata or rdata from bus
  rand bit [`LVC_AHB_MAX_DATA_WIDTH - 1:0] data[];
  rand bit [`LVC_AHB_MAX_ADDR_WIDTH - 1 : 0] addr = 0;

  // Represents the burst size of a transaction  数据位宽
  rand burst_size_enum burst_size = BURST_SIZE_8BIT;

  // Represents the burst type of a transaction 连续发送的类型（单个）
  rand burst_type_enum burst_type = SINGLE ;

  // Represents the transaction type of a transaction 
  rand xact_type_enum xact_type = IDLE_XACT;

  // Response from the slave.
  rand response_type_enum response_type  = OKAY;

  //************************************************
  // NOTE:: members possibly to be applied later
  //************************************************
  // Indicates the type of the current transfer, which can be 
  trans_type_enum trans_type;//当前的传输类型（idle 、busy、nseq、seq）
  // This array variable stores the responses for all the completed beats of transaction. Following are the possible response types
  response_type_enum all_beat_response[];  //这个动态数组存储了已经完成传输数据的返回状态类型（okey或者error）
  // Indicates the beat number of the current transfer
  int current_data_beat_num;  //表明当前传输的transaction的beat数目（data[i]中的i，本项目中只能为0，因为是SINGLE传输）
  //  Represents the current status of the transaction
  status_enum status = INITIAL;  //当前transaction的状态
  //  aborted_xact_status_enum aborted_xact_status = NOT_ABORTED; 


  // Represents the hwrite signal value when 当idle状态时，hwrite的默认值为1
  rand bit idle_xact_hwrite = 1;

  `uvm_object_utils_begin(lvc_ahb_transaction)
    `uvm_field_array_int(data, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_enum(burst_size_enum, burst_size, UVM_ALL_ON)
    `uvm_field_enum(burst_type_enum, burst_type, UVM_ALL_ON)
    `uvm_field_enum(xact_type_enum, xact_type, UVM_ALL_ON)
    `uvm_field_enum(response_type_enum, response_type, UVM_ALL_ON)
    `uvm_field_enum(trans_type_enum, trans_type, UVM_ALL_ON)
    `uvm_field_array_enum(response_type_enum, all_beat_response, UVM_ALL_ON)
    `uvm_field_int(current_data_beat_num, UVM_ALL_ON)
    `uvm_field_enum(status_enum, status, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_ahb_transaction");
    super.new(name);
  endfunction

  function void increase_data(int n = 1);//扩展data的内容（只是new了一下），因为是一个data一个data的捕捉，
    data = new[data.size + 1] (data);
    all_beat_response = new[all_beat_response.size + 1] (all_beat_response);//data[i]中的i和all_beat_respone[i]中的i保持一致
  endfunction


endclass

`endif // LVC_AHB_TRANSACTION_SV
