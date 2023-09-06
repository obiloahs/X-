`ifndef RKV_GPIO_IF_SV
`define RKV_GPIO_IF_SV

interface rkv_gpio_if;
  logic clk; // AHB bus hclk
  logic fclk;
  logic rstn;
  logic [15:0] portin;  //交互的部分，也写到总线里
  logic [15:0] portout;
  logic [15:0] porten;
  logic [15:0] portfunc;
  logic [15:0] gpioint;
  logic        combint;

  initial begin : rstn_gen
    assert_reset(10);
  end

  task automatic assert_reset(int nclks = 1, int delay = 0);
    #(delay * 1ns);
    repeat(nclks) @(posedge clk);
    rstn <= 0;
    repeat(5) @(posedge clk);
    rstn <= 1;
  endtask

  task drive_portin(logic [15:0] bits);  //把传进来的数赋值给portin；
    portin <= bits;
  endtask


endinterface


`endif // RKV_GPIO_IF_SV

