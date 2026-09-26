//------------------------------------------------------------------------------
// File        : fifo_almost_empty_test.sv
// Description : Almost-empty and empty flag test for asynchronous FIFO.
//
// Test Plan ID:
//   FIFO_TC_007 : almost_empty_test
//
// Objective:
//   Verify that:
//
//     - arempty asserts when one readable FIFO entry remains.
//     - rempty remains deasserted when one item remains.
//     - rempty asserts after the final valid entry is read.
//
// Test Flow:
//   1. Wait for reset release.
//   2. Write two directed data items.
//   3. Wait until read domain observes FIFO non-empty.
//   4. Read one item.
//   5. Check arempty=1 and rempty=0.
//   6. Read final item.
//   7. Check rempty=1 and scoreboard queue is empty.
//------------------------------------------------------------------------------

class fifo_almost_empty_test extends fifo_base_test;

  `uvm_component_utils(fifo_almost_empty_test)

  //--------------------------------------------------------------------------
  // Test Configuration
  //--------------------------------------------------------------------------

  // Write exactly two entries.
  localparam int unsigned NUM_WRITES = 2;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(
    string name = "fifo_almost_empty_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // wait_for_non_empty
  //
  // Wait for the read domain to observe available FIFO data.
  // A timeout protects against an infinite wait if write-pointer CDC or
  // empty-flag logic fails.
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
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Timeout waiting for rempty to deassert. rempty=%0b",
          vif.rempty
        )
      )
    end

    `uvm_info(
      "ALMOST_EMPTY_TEST",
      "Read domain observed FIFO non-empty condition",
      UVM_LOW
    )

  endtask

  //--------------------------------------------------------------------------
  // wait_for_empty
  //
  // Wait until the read domain observes FIFO empty after the final read.
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
        "ALMOST_EMPTY_TEST",
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
    fifo_read_sequence  read_seq;

    phase.raise_objection(this);

    `uvm_info(
      "ALMOST_EMPTY_TEST",
      "Starting almost-empty FIFO test",
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 1: Wait for initial reset and verify reset status.
    //------------------------------------------------------------------------
    wait_for_initial_reset_release();
    check_initial_reset_state();

    //------------------------------------------------------------------------
    // Step 2: Write two entries.
    //------------------------------------------------------------------------
    write_seq = fifo_write_sequence::type_id::create("write_seq");

    write_seq.num_writes = NUM_WRITES;
  

    write_seq.start(env.wagent.wseqr);

    // Wait until synchronized write pointer reaches read domain.
    wait_for_non_empty();

    //------------------------------------------------------------------------
    // Step 3: Read one entry.
    //
    // After this read, exactly one FIFO item should remain.
    //------------------------------------------------------------------------
    read_seq = fifo_read_sequence::type_id::create("first_read_seq");

    read_seq.num_reads = 1;

    read_seq.start(env.ragent.rseqr);

    // The read pointer and flags update at posedge rclk.
    // Wait until negedge rclk to sample stable post-read flags.
    @(negedge vif.rclk);

    //------------------------------------------------------------------------
    // Step 4: Check almost-empty state.
    //
    // Expected state after one of two entries is consumed:
    //
    //   arempty = 1
    //   rempty  = 0
    //------------------------------------------------------------------------
    if (vif.arempty !== 1'b1) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected arempty=1 when one entry remains, actual arempty=%0b",
          vif.arempty
        )
      )
    end

    if (vif.rempty !== 1'b0) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected rempty=0 when one entry remains, actual rempty=%0b",
          vif.rempty
        )
      )
    end

    if (env.sb.expected_q.size() != 1) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected scoreboard occupancy=1 after first read, actual=%0d",
          env.sb.expected_q.size()
        )
      )
    end

    `uvm_info(
      "ALMOST_EMPTY_TEST",
      $sformatf(
        "Almost-empty condition verified: arempty=%0b rempty=%0b occupancy=%0d",
        vif.arempty,
        vif.rempty,
        env.sb.expected_q.size()
      ),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 5: Read final FIFO entry.
    //------------------------------------------------------------------------
    read_seq = fifo_read_sequence::type_id::create("final_read_seq");

    read_seq.num_reads = 1;

    read_seq.start(env.ragent.rseqr);

    // Wait until read-domain empty flag asserts.
    wait_for_empty();

    // Give monitor and scoreboard time to publish final transaction.
    repeat (2) @(posedge vif.rclk);

    //------------------------------------------------------------------------
    // Step 6: Check final empty state.
    //------------------------------------------------------------------------
    if (vif.rempty !== 1'b1) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected rempty=1 after final read, actual rempty=%0b",
          vif.rempty
        )
      )
    end

    if (env.sb.accepted_write_count != NUM_WRITES) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected %0d accepted writes, observed %0d",
          NUM_WRITES,
          env.sb.accepted_write_count
        )
      )
    end

    if (env.sb.accepted_read_count != NUM_WRITES) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected %0d accepted reads, observed %0d",
          NUM_WRITES,
          env.sb.accepted_read_count
        )
      )
    end

    if (env.sb.compare_pass_count != NUM_WRITES) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected %0d successful comparisons, observed %0d",
          NUM_WRITES,
          env.sb.compare_pass_count
        )
      )
    end

    if (env.sb.compare_fail_count != 0) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected zero comparison failures, observed %0d",
          env.sb.compare_fail_count
        )
      )
    end

    if (env.sb.expected_q.size() != 0) begin
      `uvm_error(
        "ALMOST_EMPTY_TEST",
        $sformatf(
          "Expected empty scoreboard queue after final read, actual=%0d",
          env.sb.expected_q.size()
        )
      )
    end

    `uvm_info(
      "ALMOST_EMPTY_TEST",
      "Almost-empty FIFO test completed successfully",
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask

endclass
