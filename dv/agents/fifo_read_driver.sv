//------------------------------------------------------------------------------
// File        : fifo_read_driver.sv
// Description : UVM driver for the asynchronous FIFO read interface.
//
// The driver receives read transactions from fifo_read_sequencer and drives:
//------------------------------------------------------------------------------

class fifo_read_driver extends uvm_driver#(fifo_transaction);
`uvm_component_utils(fifo_read_driver)

virtual async_fifo_if vif;

//----------------------------------------------------------------------------
  // Constructor
//----------------------------------------------------------------------------
function new(string name ="fifo_read_driver", uvm_component parent);
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
 `uvm_error("NOVIF","No virtual interface set for read driver");
endfunction

  
//----------------------------------------------------------------------------
  // Run_phase
//----------------------------------------------------------------------------
task run_phase(uvm_phase phase);
fifo_transaction tx;
tx = fifo_transaction::type_id::create("tx");
  `uvm_info("FIFO_READ_DRIVER", $sformatf ("In Run Phase - run phase started!!"), UVM_LOW) 
forever begin    
  seq_item_port.get_next_item(tx);  
  @(negedge vif.rclk)   
    vif.rinc <= tx.rinc;
  `uvm_info(
        "FIFO_READ_DRIVER",
        $sformatf(
          "Driving read request | rinc=%0b | rempty=%0b",
          tx.rinc,
          vif.rempty
        ),
        UVM_LOW
      )
     @(posedge vif.rclk);    
    seq_item_port.item_done();
   vif.rinc <=0; 
    end
`uvm_info("FIFO_READ_DRIVER", $sformatf ("In Main Phase - main phase ended!!"), UVM_LOW)

 endtask
 endclass
