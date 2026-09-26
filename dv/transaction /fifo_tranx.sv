class fifo_transaction extends uvm_sequence_item;
 import fifo_tb_config_pkg::*;
// -----------------------------------
  // Sequence-controlled operation fields
// -----------------------------------
 
 randc bit [DSIZE-1:0] data;

// -----------------------------------
  // Monitor-observed interface signals
// ----------------------------------- 
 bit winc, rinc;

// -----------------------------------
  // Optional monitor / scoreboard fields
// -----------------------------------
  bit                  wfull;
  bit                  awfull;
  bit                  rempty;
  bit                  arempty;

  bit                  write_accepted;
  bit                  read_accepted;
  
  time                 sample_time;

// Factory registration and field macros
  // -----------------------------------
  `uvm_object_param_utils_begin(fifo_transaction #(DSIZE))
    `uvm_field_int(data,           UVM_DEFAULT)
    `uvm_field_int(winc,           UVM_DEFAULT)
    `uvm_field_int(rinc,           UVM_DEFAULT)
    `uvm_field_int(wfull,          UVM_DEFAULT)
    `uvm_field_int(awfull,         UVM_DEFAULT)
    `uvm_field_int(rempty,         UVM_DEFAULT)
    `uvm_field_int(arempty,        UVM_DEFAULT)
    `uvm_field_int(write_accepted, UVM_DEFAULT)
    `uvm_field_int(read_accepted,  UVM_DEFAULT)
  `uvm_object_utils_end

 function new(string name ="fifo_transaction");
 super.new(name);
 endfunction

 function string  convert2string();
 return $sformatf(" data=%0h, \t winc=%0h, \t rinc=%0h",data,winc,rinc);
 endfunction

 endclass
