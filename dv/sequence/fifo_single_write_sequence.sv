//------------------------------------------------------------------------------
// File        : fifo_single_write_sequence.sv
// Description : UVM sequence that generates one FIFO write transaction.
//
// The sequence sends one transaction to fifo_write_driver.
//
// Transaction convention:
//   req.write = 1 : Write transaction
//   req.data      : Data driven on FIFO wdata input
//------------------------------------------------------------------------------

class fifo_single_write_sequence extends uvm_sequence #(fifo_transaction);

  `uvm_object_utils(fifo_single_write_sequence)
   

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "fifo_single_write_sequence");
    super.new(name);
  endfunction

  //--------------------------------------------------------------------------
  // body
  //
  // Create one write transaction and send it to the write driver.
  //--------------------------------------------------------------------------
  task body();

    fifo_transaction req;

    // Create transaction using UVM factory.
    req = fifo_transaction::type_id::create("req");

    // Request ownership of the sequencer/driver transaction channel.
    start_item(req);

    // Mark this as a write transaction.
    req.winc = 1'b1;
    assert(req.randomize());

    `uvm_info(
      "SINGLE_WRITE_SEQ",
      $sformatf("Generating single write transaction: data=0x%0h",
                req.data),
      UVM_MEDIUM
    )

    // Send transaction to the write driver.
    finish_item(req);

  endtask

endclass
