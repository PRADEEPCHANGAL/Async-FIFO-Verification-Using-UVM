//------------------------------------------------------------------------------
// File        : fifo_clock_ratio_test.sv
// Description : Async FIFO clock-ratio verification test.
//
// Test Objective:
//   Verify FIFO data integrity and ordering when write and read clocks operate
//   at different frequencies.
//
// This test is designed to be run multiple times with different command-line
// clock settings.
//
// Example runs:
//
//   Write faster than read:
//     +WCLK_HALF_NS=2 +RCLK_HALF_NS=10
//
//   Read faster than write:
//     +WCLK_HALF_NS=10 +RCLK_HALF_NS=2
//
//   Non-integer ratio:
//     +WCLK_HALF_NS=5 +RCLK_HALF_NS=8
//
//   Same frequency:
//     +WCLK_HALF_NS=5 +RCLK_HALF_NS=5
//
// Test Strategy:
//   1. Wait for reset release.
//   2. Start write and read burst sequences concurrently.
//   3. Allow accepted operations to occur independently.
//   4. Check scoreboard queue for remaining entries.
//   5. Drain remaining entries.
//   6. Verify:
//        - All accepted writes are eventually read.
//        - FIFO order is preserved.
//        - No data mismatch occurs.
//        - Scoreboard queue is empty.
//        - FIFO returns to empty state.
//
// Important:
//   The test does NOT require every write attempt or read attempt to be
//   accepted. Clock ratios can naturally cause:
//      - Blocked writes when FIFO becomes full.
//      - Blocked reads when FIFO is empty.
//
// The main correctness requirement is:
//
//   accepted_write_count == accepted_read_count
//
// after all remaining FIFO entries are drained.
//------------------------------------------------------------------------------

class fifo_clock_ratio_test extends fifo_base_test;
    import fifo_tb_config_pkg::*;

  `uvm_component_utils(fifo_clock_ratio_test)

  //--------------------------------------------------------------------------
  // Test Configuration
  //
  // Generate more traffic than FIFO depth to exercise asynchronous behavior.
  //
  // For current configuration:
  //   ASIZE = 3
  //   DEPTH = 8
  //
  // Number of write/read attempts:
  //   3 * DEPTH = 24
  //
  // Some attempts may be blocked depending on selected clock ratio.
  //--------------------------------------------------------------------------

  localparam int unsigned NUM_ATTEMPTS = 3 * DEPTH;


  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(
    string name = "fifo_clock_ratio_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // wait_for_non_empty
  //
  // Wait for read domain to observe available FIFO data.
  //--------------------------------------------------------------------------
  task automatic wait_for_non_empty(
    input time timeout_value = 2_000ns
  );

    bit non_empty_seen;

    non_empty_seen = 1'b0;

    fork
      begin
        wait (vif.rempty === 1'b0);
        non_empty_seen = 1'b1;
      end

      begin
        #timeout_value;
      end
    join_any

    disable fork;

    if (!non_empty_seen) begin
      `uvm_fatal(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Timeout waiting for rempty=0 while scoreboard has pending data. rempty=%0b",
          vif.rempty
        )
      )
    end

  endtask

  //--------------------------------------------------------------------------
  // wait_for_empty
  //
  // Wait for read domain to observe FIFO empty after draining all remaining
  // expected data.
  //--------------------------------------------------------------------------

  task automatic wait_for_empty(
    input time timeout_value = 2_000ns
  );

    bit empty_seen;

    empty_seen = 1'b0;

    fork
      begin
        wait (vif.rempty === 1'b1);
        empty_seen = 1'b1;
      end

      begin
        #timeout_value;
      end
    join_any

    disable fork;

    if (!empty_seen) begin
      `uvm_fatal(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Timeout waiting for rempty=1 after drain. rempty=%0b",
          vif.rempty
        )
      )
    end

  endtask

  //--------------------------------------------------------------------------
  // run_phase
  //--------------------------------------------------------------------------

  task run_phase(uvm_phase phase);

    fifo_write_sequence write_seq;
    fifo_read_sequence  concurrent_read_seq;
    fifo_read_sequence  drain_read_seq;

    int unsigned remaining_entries;
    int unsigned accepted_writes_before_drain;

    phase.raise_objection(this);

    `uvm_info(
      "CLOCK_RATIO_TEST",
      $sformatf(
        "Starting clock-ratio test with %0d write/read attempts",
        NUM_ATTEMPTS
      ),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 1: Initial reset verification.
    //------------------------------------------------------------------------
    wait_for_initial_reset_release();
    check_initial_reset_state();

    //------------------------------------------------------------------------
    // Step 2: Create write and read traffic.
    //------------------------------------------------------------------------
    write_seq = fifo_write_sequence::type_id::create("write_seq");

    write_seq.num_writes = NUM_ATTEMPTS;

    concurrent_read_seq =
      fifo_read_sequence::type_id::create("concurrent_read_seq");

    concurrent_read_seq.num_reads = NUM_ATTEMPTS;

    //------------------------------------------------------------------------
    // Step 3: Run write and read traffic in parallel.
    //
    // Both sequences operate independently:
    //
    //   write sequence -> wclk domain
    //   read sequence  -> rclk domain
    //
    // This is the core asynchronous clock-ratio stress phase.
    //------------------------------------------------------------------------
    fork
      begin
        write_seq.start(env.wagent.wseqr);
      end

      begin
        concurrent_read_seq.start(env.ragent.rseqr);
      end
    join

    // Let monitor and scoreboard analysis writes settle.
    repeat (3) @(posedge vif.rclk);

    // Save accepted write count before final drain.
    accepted_writes_before_drain = env.sb.accepted_write_count;

    // Determine remaining functional occupancy.
    remaining_entries = env.sb.expected_q.size();

    `uvm_info(
      "CLOCK_RATIO_TEST",
      $sformatf(
        "Concurrent phase completed: accepted_writes=%0d, accepted_reads=%0d, blocked_writes=%0d, blocked_reads=%0d, remaining_entries=%0d",
        env.sb.accepted_write_count,
        env.sb.accepted_read_count,
        env.sb.blocked_write_count,
        env.sb.blocked_read_count,
        remaining_entries
      ),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 4: Drain any accepted data that remains in FIFO.
    //
    // The number of drain reads is based on scoreboard occupancy, not number
    // of attempted transactions.
    //------------------------------------------------------------------------
    if (remaining_entries > 0) begin

      // Wait for read-domain synchronized view of available data.
      wait_for_non_empty();

      drain_read_seq =
        fifo_read_sequence::type_id::create("drain_read_seq");

      drain_read_seq.num_reads = remaining_entries;

      drain_read_seq.start(env.ragent.rseqr);

      `uvm_info(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Started drain sequence for %0d remaining FIFO entries",
          remaining_entries
        ),
        UVM_LOW
      )
    end

    //------------------------------------------------------------------------
    // Step 5: Wait for FIFO empty condition.
    //------------------------------------------------------------------------
    wait_for_empty();

    // Allow final monitor and scoreboard transactions to complete.
    repeat (3) @(posedge vif.rclk);

    //------------------------------------------------------------------------
    // Step 6: Final checks.
    //------------------------------------------------------------------------

    // No new writes happen during drain phase.
    if (env.sb.accepted_write_count != accepted_writes_before_drain) begin
      `uvm_error(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Unexpected accepted write count change during drain. Before=%0d After=%0d",
          accepted_writes_before_drain,
          env.sb.accepted_write_count
        )
      )
    end

    // Every accepted write must eventually be accepted as a read.
    if (env.sb.accepted_read_count != env.sb.accepted_write_count) begin
      `uvm_error(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Accepted transaction mismatch. Accepted writes=%0d, accepted reads=%0d",
          env.sb.accepted_write_count,
          env.sb.accepted_read_count
        )
      )
    end

    // Every accepted read must match one expected FIFO item.
    if (env.sb.compare_pass_count != env.sb.accepted_read_count) begin
      `uvm_error(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Comparison count mismatch. Accepted reads=%0d, passing comparisons=%0d",
          env.sb.accepted_read_count,
          env.sb.compare_pass_count
        )
      )
    end

    if (env.sb.compare_fail_count != 0) begin
      `uvm_error(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Expected zero data mismatches, observed %0d",
          env.sb.compare_fail_count
        )
      )
    end

    if (env.sb.expected_q.size() != 0) begin
      `uvm_error(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Expected scoreboard queue to be empty after drain, actual size=%0d",
          env.sb.expected_q.size()
        )
      )
    end

    if (vif.rempty !== 1'b1) begin
      `uvm_error(
        "CLOCK_RATIO_TEST",
        $sformatf(
          "Expected rempty=1 after drain, actual rempty=%0b",
          vif.rempty
        )
      )
    end

    `uvm_info(
      "CLOCK_RATIO_TEST",
      $sformatf(
        "Clock-ratio test completed successfully. Accepted writes=%0d, blocked writes=%0d, blocked reads=%0d",
        env.sb.accepted_write_count,
        env.sb.blocked_write_count,
        env.sb.blocked_read_count
      ),
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask

endclass
