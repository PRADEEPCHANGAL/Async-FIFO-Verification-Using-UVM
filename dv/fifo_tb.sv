module fifo_tb;

  import fifo_tb_config_pkg::*;

//------------------------------------------------------------------------------
// Configurable clock generation.
//
// Clock half-periods can be overridden from simulator command line.
//
// Examples:
//   +WCLK_HALF_NS=2 +RCLK_HALF_NS=10
//      wclk period = 4 ns,  rclk period = 20 ns
//      Write clock faster than read clock.
//
//   +WCLK_HALF_NS=10 +RCLK_HALF_NS=2
//      wclk period = 20 ns, rclk period = 4 ns
//      Read clock faster than write clock.
//
//   +WCLK_HALF_NS=5 +RCLK_HALF_NS=8
//      wclk period = 10 ns, rclk period = 16 ns
//      Non-integer frequency ratio.
//------------------------------------------------------------------------------
logic wclk =0, rclk=0;
integer wclk_half_ns;
integer rclk_half_ns;

initial begin
  // Default clock configuration.
  wclk_half_ns = 5;   // wclk period = 10 ns
  rclk_half_ns = 7;   // rclk period = 14 ns

  // Override defaults using simulator plusargs, if supplied.
  void'($value$plusargs("WCLK_HALF_NS=%d", wclk_half_ns));
  void'($value$plusargs("RCLK_HALF_NS=%d", rclk_half_ns));

  // Validate clock settings.
  if (wclk_half_ns <= 0) begin
    $fatal(1, "WCLK_HALF_NS must be greater than zero");
  end

  if (rclk_half_ns <= 0) begin
    $fatal(1, "RCLK_HALF_NS must be greater than zero");
  end

  // Initialize clocks.
  wclk = 1'b0;
  rclk = 1'b0;

  $display(
    "[FIFO_TB] Clock configuration: wclk period=%0d ns, rclk period=%0d ns",
    2 * wclk_half_ns,
    2 * rclk_half_ns
  );

  // Generate both clocks independently.
  fork
    forever #(wclk_half_ns * 1ns) wclk = ~wclk;
    forever #(rclk_half_ns * 1ns) rclk = ~rclk;
  join_none
end
// ----------------------------------------
  // Interface instance
// ----------------------------------------
  async_fifo_if vif(wclk,rclk);

// ----------------------------------------
  // DUT instance
// ----------------------------------------
async_fifo#(.DSIZE(DSIZE),
    .ASIZE       (ASIZE),
            .FALLTHROUGH ("TRUE")
   ) dut(
    .wclk(wclk),
    .rclk(rclk),
    .wdata(vif.wdata),
    .winc(vif.winc),
    .wfull(vif.wfull),
    .awfull(vif.awfull),
    .rdata(vif.rdata),
    .rinc(vif.rinc),
    .rempty(vif.rempty),
    .arempty(vif.arempty),
    .rrst_n(vif.rrst_n),
    .wrst_n(vif.wrst_n)
  );

  // ----------------------------------------
  // Initial signal values and reset sequence
  // ----------------------------------------
  initial begin
    vif.wrst_n = 1'b0;
    vif.rrst_n = 1'b0;

    vif.winc   = 1'b0;
    vif.wdata  = '0;
    vif.rinc   = 1'b0;

    // Hold both reset domains active long enough
    // for multiple local clock edges.
    repeat (3) @(posedge wclk);
    repeat (3) @(posedge rclk);

    vif.wrst_n = 1'b1;
    vif.rrst_n = 1'b1;
  end

initial begin
    uvm_config_db#(virtual async_fifo_if)::set(null,"*","vif",vif);
  
  run_test("fifo_multiple_write_read_test");

  `uvm_info("FIFO_TB", $sformatf ("Test is done"), UVM_LOW)

end

// ----------------------------------------
  // Optional VCD waveform generation
// ----------------------------------------
initial begin  
  $dumpfile("dump.vcd");
  $dumpvars(0, fifo_tb);
end

initial begin
  #100_0000ns;
   `uvm_info("FIFO_TB", $sformatf ("GLOBAL_TIMEOUT: Simulation reached global timeout"), UVM_LOW)
  $finish;

end
 endmodule
