//------------------------------------------------------------------------------
// File        : fifo_single_read_sequence.sv
// Description : UVM sequence that generates one FIFO read transaction.
//
// The sequence sends one transaction to fifo_read_driver.
//
// Transaction convention:
//   req.rinc = 1 : Read transaction
//
// The read driver drives rinc=1 for one read-clock cycle.
//
// Note:
//   This sequence does not check rempty. It only requests a read.
//   The DUT decides whether the read is accepted:
//
//     read_accepted = rinc && !rempty
//
// The read monitor and scoreboard determine whether the request was accepted.
//------------------------------------------------------------------------------

class fifo_single_read_sequence extends uvm_sequence #(fifo_transaction);

  `uvm_object_utils(fifo_single_read_sequence)


  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "fifo_single_read_sequence");
    super.new(name);
  endfunction

  //--------------------------------------------------------------------------
  // body
  //
  // Create one read transaction and send it to the read driver.
  //--------------------------------------------------------------------------
  task body();

    fifo_transaction  req;

    // Create transaction using UVM factory.
    req = fifo_transaction::type_id::create("req");

    // Request ownership of the sequencer/driver transaction channel.
    start_item(req);

    // Mark this as a read transaction.
    req.rinc = 1'b1;

    // Read driver does not use data. Read monitor fills data with observed
    // DUT rdata when the read request is sampled.
    req.data = '0;

    `uvm_info(
      "SINGLE_READ_SEQ",
      "Generating single read transaction",
      UVM_MEDIUM
    )

    // Send transaction to the read driver.
    finish_item(req);

  endtask

endclass
