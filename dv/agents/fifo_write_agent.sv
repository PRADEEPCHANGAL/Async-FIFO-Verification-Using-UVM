//------------------------------------------------------------------------------
// File        : fifo_write_agent.sv
// Description : Active UVM agent for the asynchronous FIFO write interface.
//
// The write agent contains:
//
//   - fifo_write_sequencer : Receives write transactions from sequences.
//   - fifo_write_driver    : Drives winc and wdata to the DUT.
//   - fifo_write_monitor   : Observes write-side DUT activity.
//------------------------------------------------------------------------------
 
 class fifo_write_agent extends uvm_agent;
 `uvm_component_utils(fifo_write_agent)

//--------------------------------------------------------------------------
  // Write-side UVM components
//--------------------------------------------------------------------------
 fifo_write_driver wdrv;
 fifo_write_sequencer wseqr;
 fifo_write_monitor wmon;

//--------------------------------------------------------------------------
  // Constructor
//--------------------------------------------------------------------------
function new(string name ="fifo_write_agent", uvm_component parent);
super.new(name,parent);
endfunction

//--------------------------------------------------------------------------
  // build_phase
//--------------------------------------------------------------------------
function void build_phase(uvm_phase phase);
super.build_phase(phase);
wdrv = fifo_write_driver::type_id::create("wdrv",this);
wmon = fifo_write_monitor::type_id::create("wmon",this);
wseqr = fifo_write_sequencer::type_id::create("wseqr",this);
endfunction

//--------------------------------------------------------------------------
  // connect_phase
//--------------------------------------------------------------------------
function void connect_phase(uvm_phase phase);
wdrv.seq_item_port.connect(wseqr.seq_item_export);
endfunction

endclass
