//------------------------------------------------------------------------------
// File        : fifo_write_driver.sv
// Description : UVM driver for the asynchronous FIFO write interface.
//
// The driver receives write transactions from fifo_write_sequencer and drives:
//------------------------------------------------------------------------------

class fifo_write_driver extends uvm_driver#(fifo_transaction);
 `uvm_component_utils(fifo_write_driver)

 virtual async_fifo_if vif;

//----------------------------------------------------------------------------
  // Constructor
//----------------------------------------------------------------------------
function new(string name ="fifo_write_driver", uvm_component parent);
  super.new(name,parent);
endfunction

//----------------------------------------------------------------------------
  // build_phase
  //
  // Get the virtual interface from uvm_config_db.
  // The interface is configured in tb_top.
//----------------------------------------------------------------------------
function void build_phase(uvm_phase phase);
 super.build_phase(phase);
 if(!uvm_config_db #(virtual async_fifo_if)::get(this,"","vif",vif))
 `uvm_error("NOVIF","No virtual interface set for write driver");
endfunction

//----------------------------------------------------------------------------
  // Run_phase
//----------------------------------------------------------------------------
task run_phase(uvm_phase phase);
fifo_transaction tx;
tx = fifo_transaction::type_id::create("tx");
`uvm_info("FIFO_WRITE_DRIVER", $sformatf ("In Main Phase - main phase started!!"), UVM_LOW) 

forever begin    
    @(negedge vif.wclk)begin
    seq_item_port.get_next_item(tx);
    `uvm_info("FIFO_WRITE_DRIVER", $sformatf ("Write transaction driving to DUT TX =%0s",tx.convert2string), UVM_LOW)  
    vif.winc <= tx.winc;
    vif.wdata <= tx.data; 
    vif.rinc <= tx.rinc;
    @(vif.wclk);
     @(vif.wclk);
     vif.winc <=0;  
    end
    seq_item_port.item_done();
    end
`uvm_info("FIFO_WRITE_DRIVER", $sformatf ("In Main Phase - main phase ended!!"), UVM_LOW)

 endtask
 endclass
