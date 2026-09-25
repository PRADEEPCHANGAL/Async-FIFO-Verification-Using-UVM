//------------------------------------------------------------------------------
// File        : fifo_write_monitor.sv
// Description : Passive UVM monitor for the asynchronous FIFO write interface.
//
// The monitor observes write-domain signals:
//
//   - wclk
//   - wrst_n
//   - winc
//   - wdata
//   - wfull
//   - awfull
//------------------------------------------------------------------------------

class fifo_write_monitor extends uvm_monitor;
`uvm_component_utils(fifo_write_monitor)

virtual async_fifo_if vif;

fifo_transaction tx;

// Analysis port used to publish observed write transactions.
uvm_analysis_port#(fifo_transaction) wmon_ap;

//----------------------------------------------------------------------------
  // Constructor
//----------------------------------------------------------------------------
function new(string name ="fifo_write_monitor", uvm_component parent);
 super.new(name,parent);
 wmon_ap = new("wmon_ap", this);
endfunction

//----------------------------------------------------------------------------
  // build_phase
//----------------------------------------------------------------------------
function void build_phase(uvm_phase phase);
 super.build_phase(phase);
 if(!uvm_config_db #(virtual async_fifo_if)::get(this,"","vif",vif))
 `uvm_error("NOVIF","No virtual interface set for read monitor");
endfunction

task run_phase(uvm_phase phase);
tx = fifo_transaction::type_id::create("tx");
forever begin
@(posedge vif.wclk);
if (vif.wrst_n !== 1'b1)
      continue;
//`uvm_info("FIFO_WRITE_MONITOR", $sformatf ("Waiting for write enable to assert"), UVM_LOW)


  if(vif.winc)begin
  tx.winc            = vif.winc;
  tx.write_accepted   = vif.winc && !vif.wfull;
  tx.data             = vif.wdata;
  tx.wfull            = vif.wfull;
  tx.awfull           = vif.awfull;
  tx.sample_time      = $time;
  
`uvm_info("FIFO_WRITE_MONITOR", $sformatf ("Write transaction driving to DUT TX=%0s",tx.convert2string), UVM_LOW)
@( vif.wclk);
wmon_ap.write(tx);
  end
end
endtask

endclass 
