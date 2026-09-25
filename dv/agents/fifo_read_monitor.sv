//------------------------------------------------------------------------------
// File        : fifo_read_monitor.sv
// Description : Passive UVM monitor for the asynchronous FIFO read interface.
//
// The monitor observes read-domain signals:
//
//   - rclk
//   - rrst_n
//   - rinc
//   - rdata
//   - rempty
//   - arempty
//------------------------------------------------------------------------------

class fifo_read_monitor extends uvm_monitor;
`uvm_component_utils(fifo_read_monitor)

virtual async_fifo_if vif;

fifo_transaction tx;

uvm_analysis_port#(fifo_transaction) rmon_ap;

function new(string name ="fifo_read_monitor", uvm_component parent);
super.new(name,parent);
rmon_ap = new("rmon_ap", this);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
if(!uvm_config_db #(virtual async_fifo_if)::get(this,"","vif",vif))
`uvm_error("NOVIF","No virtual interface set for read monitor");
endfunction

//----------------------------------------------------------------------------
  // Run_phase
//----------------------------------------------------------------------------
task run_phase(uvm_phase phase);
forever begin
@(posedge vif.rclk);
  if (vif.rrst_n !== 1'b1)
      continue;
if(vif.rinc)begin
   tx = fifo_transaction::type_id::create("tx");
tx.rinc           = vif.rinc;
tx.read_accepted   = vif.rinc && !vif.rempty;
tx.data            = vif.rdata;
tx.rempty          = vif.rempty;
tx.arempty         = vif.arempty;
tx.sample_time     = $time;

if (tx.read_accepted) begin
  `uvm_info(
    "FIFO_READ_MONITOR",
    $sformatf(
      "ACCEPTED READ | rdata=0x%0h | rempty=%0b | arempty=%0b",
      tx.data,
      tx.rempty,
      tx.arempty
    ),
    UVM_LOW
  )
end
else begin
  `uvm_info(
    "FIFO_READ_MONITOR",
    $sformatf(
      "BLOCKED READ | rempty=%0b | rdata=0x%0h is INVALID / DON'T-CARE",
      tx.rempty,
      tx.data
    ),
    UVM_LOW
  )
end
 rmon_ap.write(tx);
  end
end
endtask

endclass 
