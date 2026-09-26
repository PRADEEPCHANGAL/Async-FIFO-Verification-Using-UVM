//------------------------------------------------------------------------------
// File        : fifo_read_only_empty_test.sv
// Description : Directed read-while-empty test for asynchronous FIFO.
//
// Test Plan ID:
//   FIFO_TC_005 : read_only_empty_test
//
// Objective:
//   Verify that read requests are blocked while FIFO is empty.
//
// Test Flow:
//   1. Wait for initial reset release.
//   2. Confirm FIFO is empty.
//   3. Generate multiple read requests without any write.
//   4. Verify all reads are blocked.
//   5. Verify scoreboard queue remains empty.
//
// Important:
//   rdata is intentionally NOT compared in this test. In FWFT mode, rdata
//   may show stale memory contents even when rempty=1.
//------------------------------------------------------------------------------

class fifo_read_only_test extends fifo_base_test;
  import fifo_tb_config_pkg::*;

  `uvm_component_utils(fifo_read_only_test)

  // Number of read attempts while FIFO remains empty.
  localparam int unsigned NUM_READ_ATTEMPTS = 4;

  //----------------------------------------------------------------------------
  // Constructor
  //----------------------------------------------------------------------------
  function new(
    string name = "fifo_read_only_empty_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //----------------------------------------------------------------------------
  // run_phase
  //----------------------------------------------------------------------------
  task run_phase(uvm_phase phase);

    fifo_read_sequence read_seq;

    phase.raise_objection(this);

    `uvm_info(
      "READ_EMPTY_TEST",
      "Starting read-while-empty FIFO test",
      UVM_LOW
    )

    //--------------------------------------------------------------------------
    // Step 1: Wait for reset release and verify reset status.
    //--------------------------------------------------------------------------
    wait_for_initial_reset_release();
    check_initial_reset_state();

    // FIFO must be empty before read attempts.
    if (vif.rempty !== 1'b1) begin
      `uvm_fatal(
        "READ_EMPTY_TEST",
        $sformatf(
          "Expected FIFO empty before test, but rempty=%0b",
          vif.rempty
        )
      )
    end

    //--------------------------------------------------------------------------
    // Step 2: Generate read requests.
    //
    // No write sequence is started. Therefore, FIFO remains empty and each
    // read request must be blocked by the DUT.
    //--------------------------------------------------------------------------
    read_seq = fifo_read_sequence::type_id::create("read_seq");

    read_seq.num_reads = NUM_READ_ATTEMPTS;

    read_seq.start(env.ragent.rseqr);

    `uvm_info(
      "READ_EMPTY_TEST",
      $sformatf(
        "Completed %0d read attempts while FIFO was empty",
        NUM_READ_ATTEMPTS
      ),
      UVM_LOW
    )

    // Allow monitor and scoreboard transactions to settle.
    repeat (2) @(posedge vif.rclk);

    //--------------------------------------------------------------------------
    // Step 3: Verify FIFO remains empty.
    //--------------------------------------------------------------------------
    if (vif.rempty !== 1'b1) begin
      `uvm_error(
        "READ_EMPTY_TEST",
        $sformatf(
          "FIFO should remain empty after blocked read attempts. rempty=%0b",
          vif.rempty
        )
      )
    end

    //--------------------------------------------------------------------------
    // Step 4: Verify scoreboard statistics.
    //--------------------------------------------------------------------------

    // No write sequence was started.
    if (env.sb.accepted_write_count != 0) begin
      `uvm_error(
        "READ_EMPTY_TEST",
        $sformatf(
          "Expected 0 accepted writes, observed %0d",
          env.sb.accepted_write_count
        )
      )
    end

    // FIFO was empty, therefore no read can be accepted.
    if (env.sb.accepted_read_count != 0) begin
      `uvm_error(
        "READ_EMPTY_TEST",
        $sformatf(
          "Expected 0 accepted reads, observed %0d",
          env.sb.accepted_read_count
        )
      )
    end

    // Every requested read should be blocked.
    if (env.sb.blocked_read_count != NUM_READ_ATTEMPTS) begin
      `uvm_error(
        "READ_EMPTY_TEST",
        $sformatf(
          "Expected %0d blocked reads, observed %0d",
          NUM_READ_ATTEMPTS,
          env.sb.blocked_read_count
        )
      )
    end

    // No accepted writes or reads means queue remains empty.
    if (env.sb.expected_q.size() != 0) begin
      `uvm_error(
        "READ_EMPTY_TEST",
        $sformatf(
          "Expected scoreboard queue size=0, actual size=%0d",
          env.sb.expected_q.size()
        )
      )
    end

    // There must be no data comparison because all reads were blocked.
    if (env.sb.compare_pass_count != 0) begin
      `uvm_error(
        "READ_EMPTY_TEST",
        $sformatf(
          "Expected 0 passing comparisons, observed %0d",
          env.sb.compare_pass_count
        )
      )
    end

    if (env.sb.compare_fail_count != 0) begin
      `uvm_error(
        "READ_EMPTY_TEST",
        $sformatf(
          "Expected 0 failing comparisons, observed %0d",
          env.sb.compare_fail_count
        )
      )
    end

    `uvm_info(
      "READ_EMPTY_TEST",
      "Read-while-empty FIFO test completed successfully",
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask

endclass
