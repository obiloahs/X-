`ifndef RKV_WATCHDOG_INTEGRATION_VIRT_SEQ_SV
`define RKV_WATCHDOG_INTEGRATION_VIRT_SEQ_SV

class rkv_watchdog_integration_virt_seq extends rkv_watchdog_base_virtual_sequence;
  `uvm_object_utils(rkv_watchdog_integration_virt_seq)
  function new (string name = "rkv_watchdog_integration_virt_seq");
    super.new(name);
  endfunction

  task body();
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    // Check WDOGINT & WDOGRES reset value
    `uvm_info("INTGTEST", "Check WDOGINT & WDOGRES reset value", UVM_LOW)
    compare_data(vif.wdogint, 1'b0);
    compare_data(vif.wdogres, 1'b0);
    // Enable integration test mode
    rgm.WDOGITCR.ITME.set(1'b1);
    rgm.WDOGITCR.update(status);
    // Check WDOGINT & WDOGRES test control value
    `uvm_info("INTGTEST", "Check WDOGINT & WDOGRES test control value", UVM_LOW)
    rgm.WDOGITOP.WDOGINT.set(1'b1);
    rgm.WDOGITOP.WDOGRES.set(1'b1);
    rgm.WDOGITOP.update(status);
    compare_data(vif.wdogint, 1'b1);
    compare_data(vif.wdogres, 1'b1);

    rgm.WDOGITOP.WDOGINT.set(1'b0);
    rgm.WDOGITOP.WDOGRES.set(1'b0);
    rgm.WDOGITOP.update(status);
    compare_data(vif.wdogint, 1'b0);
    compare_data(vif.wdogres, 1'b0);

    // Check integration test mode exit
    `uvm_info("INTGTEST", "Check integration test mode exit", UVM_LOW)
    rgm.WDOGITOP.WDOGINT.set(1'b1);
    rgm.WDOGITOP.WDOGRES.set(1'b1);
    rgm.WDOGITOP.update(status);
    compare_data(vif.wdogint, 1'b1);
    compare_data(vif.wdogres, 1'b1);

    rgm.WDOGITCR.ITME.set(1'b0);
    rgm.WDOGITCR.update(status);
    compare_data(vif.wdogint, 1'b0);
    compare_data(vif.wdogres, 1'b0);

    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask
endclass

`endif 
