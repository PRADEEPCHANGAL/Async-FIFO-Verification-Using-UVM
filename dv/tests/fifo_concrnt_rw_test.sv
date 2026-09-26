//------------------------------------------------------------------------------
// File        : fifo_concurrent_rw_test.sv
// Description : Concurrent read/write test for asynchronous FIFO.
//
// Test Plan ID:
//   FIFO_TC_009 : concurrent_rw_test
//
// Objective:
//   Verify FIFO data integrity and ordering while write and read sequences run
//   concurrently on independent clock domains.
//
// Test Flow:
//   1. Wait for reset release.
//   2. Start write burst and read burst in parallel.
//   3. Check how many items remain in scoreboard reference queue.
//   4. If items remain, drain them using additional read requests.
//   5. Verify all accepted write data was read correctly.
//
// Important:
//   Some initial read attempts may be blocked while rempty=1 because write
//   pointer synchronization into the read clock domain takes time.
//------------------------------------------------------------------------------

class fifo_concrnt_rw_test extends fifo_base_test;

  `uvm_component_utils(fifo_concrnt_rw_test)

  //--------------------------------------------------------------------------
  // Test Configuration
  //--------------------------------------------------------------------------

  localparam int unsigned NUM_TRANSFERS = 6;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(
    string name = "fifo_concurrent_rw_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // wait_for_non_empty
  //
  // Wait until read domain observes available FIFO data.
  // Used only when scoreboard says data remains after concurrent phase.
  //--------------------------------------------------------------------------
  task automatic wait_for_non_empty(
    input time timeout_value = 1_000ns
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
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Timeout waiting for rempty to deassert while FIFO data remains. rempty=%0b",
          vif.rempty
        )
      )
    end

  endtask

  //--------------------------------------------------------------------------
  // wait_for_empty
  //
  // Wait until read-domain empty flag asserts after draining FIFO.
  //--------------------------------------------------------------------------
  task automatic wait_for_empty(
    input time timeout_value = 1_000ns
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
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Timeout waiting for rempty to assert. rempty=%0b",
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

    phase.raise_objection(this);

    `uvm_info(
      "CONCURRENT_RW_TEST",
      "Starting concurrent read/write FIFO test",
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 1: Wait for reset release and verify initial flags.
    //------------------------------------------------------------------------
    wait_for_initial_reset_release();
    check_initial_reset_state();

    //------------------------------------------------------------------------
    // Step 2: Create concurrent write and read sequences.
    //------------------------------------------------------------------------
    write_seq = fifo_write_sequence::type_id::create("write_seq");

    write_seq.num_writes = NUM_TRANSFERS;

    concurrent_read_seq =
      fifo_read_sequence::type_id::create("concurrent_read_seq");

    concurrent_read_seq.num_reads = 10;

    //------------------------------------------------------------------------
    // Step 3: Start both sequences in parallel.
    //
    // Write side operates using wclk.
    // Read side operates using rclk.
    //
    // Some read requests can be blocked at the beginning because FIFO starts
    // empty and rempty may not immediately deassert after writes.
    //------------------------------------------------------------------------
    fork
      begin
        write_seq.start(env.wagent.wseqr);
      end

      begin
        concurrent_read_seq.start(env.ragent.rseqr);
      end
    join

    `uvm_info(
      "CONCURRENT_RW_TEST",
      "Concurrent write/read sequence phase completed",
      UVM_LOW
    )

    // Allow monitor-to-scoreboard analysis transactions to settle.
    repeat (2) @(posedge vif.rclk);

    //------------------------------------------------------------------------
    // Step 4: Determine how many accepted write entries remain unread.
    //
    // expected_q contains:
    //
    //   accepted writes - accepted reads
    //------------------------------------------------------------------------
    remaining_entries = env.sb.expected_q.size();

    `uvm_info(
      "CONCURRENT_RW_TEST",
      $sformatf(
        "After concurrent phase: remaining scoreboard entries = %0d",
        remaining_entries
      ),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 5: Drain any data remaining after concurrent phase.
    //
    // If no data remains, concurrent reads already consumed all accepted
    // writes and no drain sequence is required.
    //------------------------------------------------------------------------
    if (remaining_entries > 0) begin

      // Since scoreboard says entries remain, wait until read domain observes
      // them through the synchronized write pointer.
      wait_for_non_empty();

      drain_read_seq =
        fifo_read_sequence::type_id::create("drain_read_seq");

      drain_read_seq.num_reads = remaining_entries;

      drain_read_seq.start(env.ragent.rseqr);

      `uvm_info(
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Started drain read sequence for %0d remaining entries",
          remaining_entries
        ),
        UVM_LOW
      )
    end

    // Wait until FIFO becomes empty after all data is consumed.
    wait_for_empty();

    // Allow final read monitor and scoreboard updates to complete.
    repeat (2) @(posedge vif.rclk);

    //------------------------------------------------------------------------
    // Step 6: Final checks.
    //------------------------------------------------------------------------

    // All write requests should be accepted because NUM_TRANSFERS < DEPTH.
    if (env.sb.accepted_write_count != NUM_TRANSFERS) begin
      `uvm_error(
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Expected %0d accepted writes, observed %0d",
          NUM_TRANSFERS,
          env.sb.accepted_write_count
        )
      )
    end

    // All accepted writes must eventually be read.
    if (env.sb.accepted_read_count != NUM_TRANSFERS) begin
      `uvm_error(
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Expected %0d accepted reads after drain, observed %0d",
          NUM_TRANSFERS,
          env.sb.accepted_read_count
        )
      )
    end

    // Every accepted read must match expected FIFO order.
    if (env.sb.compare_pass_count != NUM_TRANSFERS) begin
      `uvm_error(
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Expected %0d successful data comparisons, observed %0d",
          NUM_TRANSFERS,
          env.sb.compare_pass_count
        )
      )
    end

    if (env.sb.compare_fail_count != 0) begin
      `uvm_error(
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Expected zero data mismatches, observed %0d",
          env.sb.compare_fail_count
        )
      )
    end

    if (env.sb.expected_q.size() != 0) begin
      `uvm_error(
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Expected empty scoreboard queue, actual occupancy=%0d",
          env.sb.expected_q.size()
        )
      )
    end

    if (vif.rempty !== 1'b1) begin
      `uvm_error(
        "CONCURRENT_RW_TEST",
        $sformatf(
          "Expected rempty=1 after drain, actual rempty=%0b",
          vif.rempty
        )
      )
    end

    `uvm_info(
      "CONCURRENT_RW_TEST",
      $sformatf(
        "Concurrent read/write test passed. Blocked reads observed=%0d",
        env.sb.blocked_read_count
      ),
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask

endclass
