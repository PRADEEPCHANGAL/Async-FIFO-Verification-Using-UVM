 class fifo_write_sequencer extends uvm_sequencer #(fifo_transaction);
 `uvm_component_utils(fifo_write_sequencer)
 function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
 endclass

 class fifo_read_sequencer extends uvm_sequencer #(fifo_transaction);
 `uvm_component_utils(fifo_read_sequencer)
 function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
 endclass
