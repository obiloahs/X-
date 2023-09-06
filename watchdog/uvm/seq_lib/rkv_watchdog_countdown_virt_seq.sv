`ifndef RKV_WATCHDOG_COUNTDOWN_VIRT_SEQ_SV
`define RKV_WATCHDOG_COUNTDOWN_VIRT_SEQ_SV


class rkv_watchdog_countdown_virt_seq extends rkv_watchdog_base_virtual_sequence;
  `uvm_object_utils(rkv_watchdog_countdown_virt_seq)

  function new (string name = "rkv_watchdog_countdown_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    // Enable Watchdog and its interrupt generation
    `uvm_do(reg_enable_intr)
    // Load watchdog counter
    `uvm_do_with(reg_loadcount, {load_val == 'hFF;})
    // Wait interrupt and clear
    repeat(2) begin
      fork
        `uvm_do_with(reg_intr_wait_clear, {intval == 50; delay inside {[30:40]};})
        wait_intr_signal_released();
      join
    end

    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

endclass


`endif 
