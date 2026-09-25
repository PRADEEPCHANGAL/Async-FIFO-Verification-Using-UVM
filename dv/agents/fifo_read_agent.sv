//------------------------------------------------------------------------------
// File        : fifo_read_agent.sv
// Description : Active UVM agent for the asynchronous FIFO read interface.
//
// The read agent contains:
//
//   - fifo_read_sequencer : Receives read transactions from sequences.
//   - fifo_read_driver    : Drives rinc to the DUT.
//   - fifo_read_monitor   : Observes read-side DUT activity.
//------------------------------------------------------------------------------
 
class fifo_read_agent extends uvm_agent;
 `uvm_component_utils(fifo_read_agent)

//--------------------------------------------------------------------------
  // Read-side UVM components
//--------------------------------------------------------------------------
 fifo_read_driver rdrv;
 fifo_read_sequencer rseqr;
 fifo_read_monitor rmon;

//--------------------------------------------------------------------------
  // Constructor
//--------------------------------------------------------------------------
function new(string name ="fifo_read_agent", uvm_component parent);
super.new(name,parent);
endfunction

//--------------------------------------------------------------------------
  // build_phase
//--------------------------------------------------------------------------
function void build_phase(uvm_phase phase);
super.build_phase(phase);
rdrv = fifo_read_driver::type_id::create("rdrv",this);
rmon = fifo_read_monitor::type_id::create("rmon",this);
rseqr = fifo_read_sequencer::type_id::create("rseqr",this);
endfunction

//--------------------------------------------------------------------------
  // connect_phase
//--------------------------------------------------------------------------
function void connect_phase(uvm_phase phase);
rdrv.seq_item_port.connect(rseqr.seq_item_export);
endfunction

endclass
