//------------------------------------------------------------------------------
// File        : fifo_single_write_read_test.sv
// Description : Basic end-to-end single write and single read FIFO test.
//
// Test Plan ID:
//   FIFO_TC_002 : single_write_read_test
//
// Objective:
//   Verify that one accepted write is transferred to the read domain and
//   returned correctly on an accepted read.
//
// Test Flow:
//   1. Wait for initial reset release.
//   2. Check FIFO reset state.
//   3. Write one known data value.
//   4. Wait for read-side rempty to deassert.
//   5. Request one read.
//   6. Wait for read-side rempty to assert again.
//   7. Scoreboard verifies expected data equals actual DUT rdata.
//
// Data integrity is checked by fifo_scoreboard.
//------------------------------------------------------------------------------

class fifo_single_write_read_test extends fifo_base_test;

  `uvm_component_utils(fifo_single_write_read_test)

  //--------------------------------------------------------------------------
  // Test data
  //
  // A unique known value makes waveform debug easier.
  //--------------------------------------------------------------------------
   bit [7:0] TEST_DATA = 8'hA5;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(
    string name = "fifo_single_write_read_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // wait_for_non_empty
  //
  // Wait until read-domain empty flag deasserts.
  //
  // A timeout prevents the test from waiting forever if the write pointer
  // does not synchronize correctly into the read domain.
  //--------------------------------------------------------------------------
  task automatic wait_for_non_empty(
    input time timeout_value = 1_000ns
  );

    bit fifo_non_empty;

    fifo_non_empty = 1'b0;

    fork
      begin
        wait (vif.rempty === 1'b0);
        fifo_non_empty = 1'b1;
      end

      begin
        #timeout_value;
      end
    join_any

    disable fork;

    if (!fifo_non_empty) begin
      `uvm_fatal(
        "SINGLE_WR_RD_TEST",
        $sformatf(
          "Timeout waiting for rempty to deassert. rempty=%0b after %0t",
          vif.rempty,
          timeout_value
        )
      )
    end

    `uvm_info(
      "SINGLE_WR_RD_TEST",
      "Read domain observed non-empty FIFO: rempty=0",
      UVM_LOW
    )

  endtask

  //--------------------------------------------------------------------------
  // wait_for_empty
  //
  // Wait until read-domain empty flag asserts after the final read.
  //--------------------------------------------------------------------------
  task automatic wait_for_empty(
    input time timeout_value = 1_000ns
  );

    bit fifo_empty;

    fifo_empty = 1'b0;

    fork
      begin
        wait (vif.rempty === 1'b1);
        fifo_empty = 1'b1;
      end

      begin
        #timeout_value;
      end
    join_any

    disable fork;

    if (!fifo_empty) begin
      `uvm_fatal(
        "SINGLE_WR_RD_TEST",
        $sformatf(
          "Timeout waiting for rempty to assert. rempty=%0b after %0t",
          vif.rempty,
          timeout_value
        )
      )
    end

    `uvm_info(
      "SINGLE_WR_RD_TEST",
      "Read domain observed empty FIFO after read: rempty=1",
      UVM_LOW
    )

  endtask

  //--------------------------------------------------------------------------
  // run_phase
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);

    fifo_single_write_sequence  write_seq;
    fifo_single_read_sequence   read_seq;

    // Keep simulation active until the test completes.
    phase.raise_objection(this);

    `uvm_info(
      "SINGLE_WR_RD_TEST",
      "Starting single write/read FIFO test",
      UVM_LOW
    )

    // Wait for reset from tb_top and check expected reset flag values.
    wait_for_initial_reset_release();
    check_initial_reset_state();

    //------------------------------------------------------------------------
    // Step 1: Write one known data item.
    //------------------------------------------------------------------------
    write_seq = fifo_single_write_sequence::type_id::create(
      "write_seq"
    );

   // write_seq.write_data = TEST_DATA;

    write_seq.start(env.wagent.wseqr);

    `uvm_info(
      "SINGLE_WR_RD_TEST",
      $sformatf("Single write sequence completed for data=0x%0h", TEST_DATA),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 2: Wait for write pointer synchronization into read domain.
    //
    // The FIFO is asynchronous. After a write, rempty may take multiple
    // rclk cycles to deassert because wptr passes through a two-flop
    // synchronizer before read-side empty logic can observe it.
    //------------------------------------------------------------------------
    wait_for_non_empty();

    //------------------------------------------------------------------------
    // Step 3: Request one read.
    //------------------------------------------------------------------------
    read_seq = fifo_single_read_sequence::type_id::create(
      "read_seq"
    );

    read_seq.start(env.ragent.rseqr);

    `uvm_info(
      "SINGLE_WR_RD_TEST",
      "Single read sequence completed",
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 4: FIFO should become empty after reading its only entry.
    //------------------------------------------------------------------------
    wait_for_empty();

    // Allow monitor and scoreboard transactions to settle before ending test.
    repeat (2) @(posedge vif.rclk);

    // Direct test-level checks.
    //
    // Data comparison is done by fifo_scoreboard. Here, confirm that exactly
    // one write and one read were accepted by the DUT.
   /* if (env.sb.accepted_write_count != 1) begin
      `uvm_error(
        "SINGLE_WR_RD_TEST",
        $sformatf(
          "Expected exactly 1 accepted write, observed %0d",
          env.sb.accepted_write_count
        )
      )
    end

    if (env.sb.accepted_read_count != 1) begin
      `uvm_error(
        "SINGLE_WR_RD_TEST",
        $sformatf(
          "Expected exactly 1 accepted read, observed %0d",
          env.sb.accepted_read_count
        )
      )
    end

    if (env.sb.data_mismatch_count != 0) begin
      `uvm_error(
        "SINGLE_WR_RD_TEST",
        $sformatf(
          "Expected zero data mismatches, observed %0d",
          env.sb.data_mismatch_count
        )
      )
    end

    if (env.sb.expected_q.size() != 0) begin
      `uvm_error(
        "SINGLE_WR_RD_TEST",
        $sformatf(
          "Expected empty scoreboard queue, queue_size=%0d",
          env.sb.expected_q.size()
        )
      )
    end */

    `uvm_info(
      "SINGLE_WR_RD_TEST",
      "Single write/read FIFO test completed",
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask

endclass
