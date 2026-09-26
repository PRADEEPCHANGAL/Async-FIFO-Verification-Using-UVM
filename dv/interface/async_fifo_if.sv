interface async_fifo_if #(parameter DSIZE =8) 
 (input bit wclk, input bit rclk);

// -------------------------
  // Write-side DUT signals
// -------------------------
logic wrst_n;
logic winc;
logic [DSIZE-1:0] wdata;
logic wfull;
logic awfull;

// -------------------------
  // Read-side DUT signals
// -------------------------
logic rrst_n;
logic rinc;
logic [DSIZE-1:0] rdata;
logic rempty;
logic arempty;

clocking cb_write @(posedge wclk);
 output winc, wdata;
 input wfull, awfull;
endclocking

clocking cb_read @(posedge rclk);
 output rinc;
 input rempty,arempty,rdata;
endclocking

endinterface 
