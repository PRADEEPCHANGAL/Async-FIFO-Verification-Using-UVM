//------------------------------------------------------------------------------
// File        : fifo_fwft_test.sv
// Description : First-Word Fall-Through (FWFT) test for asynchronous FIFO.
//
// Test Plan ID:
//   FIFO_TC_008 : fwft_test
//
// DUT Configuration:
//   FALLTHROUGH = "TRUE"
//
// RTL Read Path:
//
//   assign rdata = mem[raddr];
//
// Objective:
//   Verify that the first written FIFO word becomes visible on rdata before
//   a read request is asserted.
//
// Test Flow:
//   1. Wait for reset release.
//   2. Write one known data value.
//   3. Wait until rempty deasserts in the read domain.
//   4. Do NOT issue a read request yet.
//   5. Verify:
//        - rinc   = 0
//        - rempty = 0
//        - rdata  = written data
//   6. Issue one read request.
//   7. Verify scoreboard data comparison and FIFO empty condition.
//------------------------------------------------------------------------------

class fifo_fwft_test extends fifo_base_test;

  `uvm_component_utils(fifo_fwft_test)


  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(
    string name = "fifo_fwft_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // wait_for_non_empty
  //
  // Wait until read-domain empty flag deasserts.
  //
  // After a write, the write pointer must cross from wclk domain to rclk
  // domain through the two-flop synchronizer. Therefore, rempty may not
  // deassert immediately after the write.
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
        "FWFT_TEST",
        $sformatf(
          "Timeout waiting for rempty to deassert. Current rempty=%0b",
          vif.rempty
        )
      )
    end

    `uvm_info(
      "FWFT_TEST",
      "Read domain observed FIFO non-empty condition: rempty=0",
      UVM_LOW
    )

  endtask

  //--------------------------------------------------------------------------
  // wait_for_empty
  //
  // Wait until FIFO becomes empty after the single valid read.
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
        "FWFT_TEST",
        $sformatf(
          "Timeout waiting for rempty to assert. Current rempty=%0b",
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
      "FWFT_TEST",
      "Starting First-Word Fall-Through FIFO test",
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 1: Wait for initial reset and verify reset flags.
    //------------------------------------------------------------------------
    wait_for_initial_reset_release();
    check_initial_reset_state();

    //------------------------------------------------------------------------
    // Step 2: Write one known data item.
    //------------------------------------------------------------------------
    write_seq = fifo_write_sequence::type_id::create("write_seq");

    write_seq.num_writes = 1;

    write_seq.start(env.wagent.wseqr);

    `uvm_info(
      "FWFT_TEST",
      $sformatf(
        "Completed one write transaction"
      ),
      UVM_LOW
    )

    //------------------------------------------------------------------------
    // Step 3: Wait until read domain safely observes available FIFO data.
    //------------------------------------------------------------------------
    wait_for_non_empty();

    // Wait until a stable point in the read clock cycle.
    //
    // This avoids checking exactly at a possible nonblocking-assignment update
    // boundary. No read request has been generated yet.
    @(negedge vif.rclk);

    //------------------------------------------------------------------------
    // Step 4: FWFT check.
    //
    // At this point:
    //
    //   rempty = 0
    //   rinc   = 0
    //   rdata  = TEST_DATA
    //
    // This proves that data is visible before a read request is asserted.
    //------------------------------------------------------------------------

    if (vif.rinc !== 1'b0) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "FWFT check failed: expected rinc=0 before read request, actual rinc=%0b",
          vif.rinc
        )
      )
    end

    if (vif.rempty !== 1'b0) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "FWFT check failed: expected rempty=0, actual rempty=%0b",
          vif.rempty
        )
      )
    end

    if (vif.rdata !== write_seq.wtx.data) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "FWFT DATA MISMATCH: expected rdata=0x%0h before read request, actual rdata=0x%0h",
          write_seq.wtx.data,
          vif.rdata
        )
      )
    end
    else begin 
      `uvm_info(
        "FWFT_TEST",
        $sformatf(
          "FWFT check passed: rdata=0x%0h is visible while rinc=0",
          vif.rdata
        ),
        UVM_LOW
      )
    end

    //------------------------------------------------------------------------
    // Step 5: Issue one read request.
    //------------------------------------------------------------------------
    read_seq = fifo_read_sequence::type_id::create("read_seq");

    read_seq.num_reads = 1;

    read_seq.start(env.ragent.rseqr);

    //------------------------------------------------------------------------
    // Step 6: FIFO should become empty after consuming the only item.
    //------------------------------------------------------------------------
    wait_for_empty();

    // Allow read monitor and scoreboard to process final transaction.
    repeat (2) @(posedge vif.rclk);

    //------------------------------------------------------------------------
    // Step 7: Final checks.
    //------------------------------------------------------------------------

    if (env.sb.accepted_write_count != 1) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "Expected 1 accepted write, observed %0d",
          env.sb.accepted_write_count
        )
      )
    end

    if (env.sb.accepted_read_count != 1) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "Expected 1 accepted read, observed %0d",
          env.sb.accepted_read_count
        )
      )
    end

    if (env.sb.compare_pass_count != 1) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "Expected 1 successful data comparison, observed %0d",
          env.sb.compare_pass_count
        )
      )
    end

    if (env.sb.compare_fail_count != 0) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "Expected 0 data comparison failures, observed %0d",
          env.sb.compare_fail_count
        )
      )
    end

    if (env.sb.expected_q.size() != 0) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "Expected empty scoreboard queue, actual occupancy=%0d",
          env.sb.expected_q.size()
        )
      )
    end

    if (vif.rempty !== 1'b1) begin
      `uvm_error(
        "FWFT_TEST",
        $sformatf(
          "Expected rempty=1 after final read, actual rempty=%0b",
          vif.rempty
        )
      )
    end

    `uvm_info(
      "FWFT_TEST",
      "First-Word Fall-Through FIFO test completed successfully",
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask

endclass
