//------------------------------------------------------------------------------
// File        : fifo_almost_full_test.sv
// Description : Almost-full and full flag test for asynchronous FIFO.
//
// Test Plan ID:
//   FIFO_TC_006 : almost_full_test
//
// Objective:
//   Verify that:
//
//     - awfull asserts when one writable FIFO location remains.
//     - wfull remains deasserted when one writable location remains.
//     - wfull asserts after the final FIFO location is written.
//
// For FIFO depth DEPTH:
//
//     Occupancy = DEPTH - 1:
//         awfull = 1
//         wfull  = 0
//
//     Occupancy = DEPTH:
//         wfull  = 1
//
// Current example configuration:
//
//     ASIZE = 3
//     DEPTH = 8
//
// Therefore:
//
//     After 7 writes:
//         awfull = 1, wfull = 0
//
//     After 8 writes:
//         wfull = 1
//
// Note:
//   This test intentionally does not read FIFO data. The scoreboard reference
//   queue is expected to contain DEPTH entries at the end of the test.
//------------------------------------------------------------------------------

class fifo_almost_full_test extends fifo_base_test;
  import fifo_tb_config_pkg::*;

  `uvm_component_utils(fifo_almost_full_test)


  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(
    string name = "fifo_almost_full_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // wait_for_write_flag_settle
  //
  // The DUT updates wfull and awfull on posedge wclk using nonblocking
  // assignments. Waiting until negedge wclk ensures the updated values are
  // stable before test-level checks are performed.
  //--------------------------------------------------------------------------

  task automatic wait_for_write_flag_settle();
    @(negedge vif.wclk);
  endtask

  //--------------------------------------------------------------------------
  // run_phase
  //--------------------------------------------------------------------------

  task run_phase(uvm_phase phase);

    fifo_write_sequence almost_full_write_seq;
    fifo_write_sequence final_write_seq;

    phase.raise_objection(this);

    `uvm_info(
      "ALMOST_FULL_TEST",
      $sformatf(
        "Starting almost-full test. FIFO depth = %0d entries",
        DEPTH
      ),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 1: Wait for reset release and verify reset state.
    //------------------------------------------------------------------------
    wait_for_initial_reset_release();
    check_initial_reset_state();

    //------------------------------------------------------------------------
    // Step 2: Write DEPTH-1 entries.
    //
    // For DEPTH=8, this writes 7 entries.
    // The FIFO should have one writable location remaining.
    //------------------------------------------------------------------------
    almost_full_write_seq =
      fifo_write_sequence::type_id::create(
        "almost_full_write_seq"
      );

    almost_full_write_seq.num_writes = DEPTH - 1;
   

    almost_full_write_seq.start(env.wagent.wseqr);

    // Wait for write-side flags to update after final burst write.
    wait_for_write_flag_settle();

    //------------------------------------------------------------------------
    // Step 3: Check almost-full condition.
    //------------------------------------------------------------------------

    if (vif.awfull !== 1'b1) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected awfull=1 after %0d accepted writes, actual awfull=%0b",
          DEPTH - 1,
          vif.awfull
        )
      )
    end

    if (vif.wfull !== 1'b0) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected wfull=0 after %0d accepted writes, actual wfull=%0b",
          DEPTH - 1,
          vif.wfull
        )
      )
    end

    if (env.sb.accepted_write_count != (DEPTH - 1)) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected %0d accepted writes, observed %0d",
          DEPTH - 1,
          env.sb.accepted_write_count
        )
      )
    end

    if (env.sb.expected_q.size() != (DEPTH - 1)) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected scoreboard occupancy=%0d, actual occupancy=%0d",
          DEPTH - 1,
          env.sb.expected_q.size()
        )
      )
    end

    `uvm_info(
      "ALMOST_FULL_TEST",
      $sformatf(
        "Almost-full condition verified: occupancy=%0d/%0d, awfull=%0b, wfull=%0b",
        env.sb.expected_q.size(),
        DEPTH,
        vif.awfull,
        vif.wfull
      ),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 4: Perform one final write.
    //
    // This should fill the final available FIFO location and cause wfull to
    // assert in the write clock domain.
    //------------------------------------------------------------------------
    final_write_seq = fifo_write_sequence::type_id::create(
      "final_write_seq"
    );

    final_write_seq.num_writes = 1;

    final_write_seq.start(env.wagent.wseqr);

    // Wait for write-side status flag update.
    wait_for_write_flag_settle();

    //------------------------------------------------------------------------
    // Step 5: Check full condition.
    //------------------------------------------------------------------------

    if (vif.wfull !== 1'b1) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected wfull=1 after %0d accepted writes, actual wfull=%0b",
          DEPTH,
          vif.wfull
        )
      )
    end

    if (env.sb.accepted_write_count != DEPTH) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected %0d accepted writes after final write, observed %0d",
          DEPTH,
          env.sb.accepted_write_count
        )
      )
    end

    if (env.sb.blocked_write_count != 0) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected 0 blocked writes, observed %0d",
          env.sb.blocked_write_count
        )
      )
    end

    if (env.sb.expected_q.size() != DEPTH) begin
      `uvm_error(
        "ALMOST_FULL_TEST",
        $sformatf(
          "Expected scoreboard occupancy=%0d, actual occupancy=%0d",
          DEPTH,
          env.sb.expected_q.size()
        )
      )
    end

    `uvm_info(
      "ALMOST_FULL_TEST",
      $sformatf(
        "Full condition verified: occupancy=%0d/%0d, wfull=%0b",
        env.sb.expected_q.size(),
        DEPTH,
        vif.wfull
      ),
      UVM_LOW
    )

    // This is intentionally a write-only boundary test.
    // No reads are generated, so scoreboard queue occupancy remains DEPTH.
    phase.drop_objection(this);

  endtask

endclass
