//------------------------------------------------------------------------------
// File        : fifo_sb.sv
// Description : Scoreboard / reference model for asynchronous FIFO.
//
// The scoreboard receives transactions from:
//
//   fifo_write_monitor --> sb_export_write
//   fifo_read_monitor  --> sb_export_read
//
// Reference FIFO model:
//
//   Accepted write:
//       expected_q.push_back(trans.data);
//
//   Accepted read:
//       expected_data = expected_q.pop_front();
//       Compare expected_data with trans.data.
//
// Important:
//
//   Only accepted transactions modify the reference queue.
//
//   write_accepted = winc && !wfull;
//   read_accepted  = rinc && !rempty;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Create two analysis implementation types.
//
// These macros create:
//
//   uvm_analysis_imp_W  --> calls write_W()
//   uvm_analysis_imp_R  --> calls write_R()
//------------------------------------------------------------------------------
`uvm_analysis_imp_decl(_W)
`uvm_analysis_imp_decl(_R)


class fifo_sb extends uvm_scoreboard;
import fifo_tb_config_pkg::*;
  
  `uvm_component_utils(fifo_sb)

  //----------------------------------------------------------------------------
  // Virtual Interface
  //
  // The scoreboard does not require the interface for basic queue-based data
  // comparison. It is retained here for future direct flag checks/debug.
  //----------------------------------------------------------------------------
  virtual async_fifo_if #(DSIZE) vif;

  //----------------------------------------------------------------------------
  // Analysis implementation exports
  //
  // Write monitor connects to sb_export_write.
  // Read monitor connects to sb_export_read.
  //----------------------------------------------------------------------------
  uvm_analysis_imp_W #(
    fifo_transaction #(DSIZE),
    fifo_sb          #(DSIZE)
  ) sb_export_write;

  uvm_analysis_imp_R #(
    fifo_transaction #(DSIZE),
    fifo_sb          #(DSIZE)
  ) sb_export_read;

  //----------------------------------------------------------------------------
  // Reference FIFO Queue
  //
  // Accepted writes are added at the queue back.
  // Accepted reads are removed from the queue front.
  //
  // This naturally models FIFO order.
  //----------------------------------------------------------------------------
  bit [DSIZE-1:0] expected_q[$];

  // FIFO depth derived from address size.
  //
  // Example:
  //   ASIZE = 3
  //   DEPTH = 2^3 = 8 entries
  localparam int DEPTH = (1 << ASIZE);

  // Maximum reference FIFO occupancy observed during the test.
  int unsigned max_occupancy;
  //----------------------------------------------------------------------------
  // Scoreboard Statistics
  //----------------------------------------------------------------------------
  int unsigned accepted_write_count;
  int unsigned blocked_write_count;

  int unsigned accepted_read_count;
  int unsigned blocked_read_count;

  int unsigned compare_pass_count;
  int unsigned compare_fail_count;

  //----------------------------------------------------------------------------
  // Constructor
  //----------------------------------------------------------------------------
  function new(
    string name = "fifo_sb",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  //----------------------------------------------------------------------------
  // build_phase
  //
  // Create analysis exports and get the virtual interface.
  //----------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create write-side analysis export.
    sb_export_write = new("sb_export_write", this);

    // Create read-side analysis export.
    sb_export_read = new("sb_export_read", this);

    // Get virtual interface from tb_top through uvm_config_db.
    if (!uvm_config_db#(virtual async_fifo_if #(DSIZE))::get(
      this,
      "",
      "vif",
      vif
    )) begin
      `uvm_fatal(
        "FIFO_SB",
        "Virtual interface was not found in uvm_config_db"
      )
    end
  endfunction

  //----------------------------------------------------------------------------
  // write_W
  //
  // Called automatically when fifo_write_monitor sends a write transaction.
  //
  // Expected monitor fields:
  //
  //   trans.winc          = 1
  //   trans.data            = observed wdata
  //   trans.write_accepted  = winc && !wfull
  //
  // Only accepted writes enter the expected FIFO queue.
  //----------------------------------------------------------------------------
  virtual function void write_W(
    fifo_transaction #(DSIZE) trans
  );

    // Defensive check: write monitor should send write transactions only.
    if (!trans.winc) begin
      `uvm_error(
        "FIFO_SB",
        "Write analysis export received a transaction with winc=0"
      )
      return;
    end

    // Accepted write:
    // Add data to back of reference FIFO queue.
    if (trans.write_accepted) begin

  expected_q.push_back(trans.data);
  accepted_write_count++;

  // Record maximum FIFO occupancy seen during this test.
  if (expected_q.size() > max_occupancy) begin
    max_occupancy = expected_q.size();
  end

  // Queue must never exceed configured FIFO depth.
  if (expected_q.size() > DEPTH) begin
    `uvm_error(
      "FIFO_SB",
      $sformatf(
        "REFERENCE MODEL OVERFLOW: queue_size=%0d exceeds FIFO depth=%0d",
        expected_q.size(),
        DEPTH
      )
    )
  end

  `uvm_info(
    "FIFO_SB",
    $sformatf(
      "ACCEPTED WRITE | data=0x%0h | occupancy=%0d/%0d | time=%0t",
      trans.data,
      expected_q.size(),
      DEPTH,
      trans.sample_time
    ),
    UVM_MEDIUM
  )
end

    // Blocked write:
    // FIFO was full, so no data should enter the queue.
    else begin

      blocked_write_count++;

      `uvm_info(
        "FIFO_SB",
        $sformatf(
          "BLOCKED WRITE | data=0x%0h | wfull=%0b | expected_queue_size=%0d | time=%0t",
          trans.data,
          trans.wfull,
          expected_q.size(),
          trans.sample_time
        ),
        UVM_MEDIUM
      )
    end

  endfunction : write_W

  //----------------------------------------------------------------------------
  // write_R
  //
  // Called automatically when fifo_read_monitor sends a read transaction.
  //
  // Expected monitor fields:
  //
  //   trans.write          = 0
  //   trans.data           = sampled DUT rdata
  //   trans.read_accepted  = rinc && !rempty
  //
  // On accepted read:
  //
  //   1. Remove oldest expected item from expected_q.
  //   2. Compare it against DUT rdata.
  //
  // On blocked read:
  //
  //   Do not modify expected_q.
  //----------------------------------------------------------------------------
  virtual function void write_R(
    fifo_transaction #(DSIZE) trans
  );

    bit [DSIZE-1:0] expected_data;

    // Defensive check: read monitor should send read transactions only.
    if (!trans.rinc) begin
      `uvm_error(
        "FIFO_SB",
        "Read analysis export received a transaction with rinc=0"
      )
      return;
    end

    // Accepted read:
    if (trans.read_accepted) begin

      accepted_read_count++;

      // A legal accepted read must correspond to previously accepted write data.
      if (expected_q.size() == 0) begin
        compare_fail_count++;

        `uvm_error(
          "FIFO_SB",
          $sformatf(
            "REFERENCE QUEUE UNDERFLOW | Accepted read has no expected data | actual_rdata=0x%0h | time=%0t",
            trans.data,
            trans.sample_time
          )
        )

        return;
      end

      // FIFO behavior: first accepted write must be first accepted read.
      expected_data = expected_q.pop_front();

      // Use !== so X/Z data is treated as a mismatch.
      if (trans.data !== expected_data) begin

        compare_fail_count++;

        `uvm_error(
          "FIFO_SB",
          $sformatf(
            "DATA MISMATCH | expected=0x%0h | actual=0x%0h | queue_size_after_read=%0d | time=%0t",
            expected_data,
            trans.data,
            expected_q.size(),
            trans.sample_time
          )
        )
      end

      else begin

        compare_pass_count++;

        `uvm_info(
  "FIFO_SB",
  $sformatf(
    "DATA MATCH | data=0x%0h | occupancy=%0d/%0d | time=%0t",
    trans.data,
    expected_q.size(),
    DEPTH,
    trans.sample_time
  ),
  UVM_MEDIUM
)
      end
    end

    // Blocked read:
    // FIFO was empty, so expected queue must remain unchanged.
    else begin

      blocked_read_count++;

      `uvm_info(
        "FIFO_SB",
        $sformatf(
          "BLOCKED READ | rempty=%0b | expected_queue_size=%0d | time=%0t",
          trans.rempty,
          expected_q.size(),
          trans.sample_time
        ),
        UVM_MEDIUM
      )
    end

  endfunction : write_R

//------------------------------------------------------------------------------
// report_phase
//
// Print final scoreboard statistics after the UVM test completes.
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// report_phase
//
// Print FIFO usage and scoreboard statistics at end of test.
//------------------------------------------------------------------------------
function void report_phase(uvm_phase phase);
  super.report_phase(phase);

  `uvm_info(
    "FIFO_SB_SUMMARY",
    $sformatf(
      "==================================================\nFIFO SCOREBOARD SUMMARY\n==================================================\nFIFO Data Width          : %0d bits\nFIFO Address Width       : %0d bits\nFIFO Configured Depth    : %0d entries\n--------------------------------------------------\nAccepted Writes          : %0d\nBlocked Writes           : %0d\nAccepted Reads           : %0d\nBlocked Reads            : %0d\n--------------------------------------------------\nCurrent FIFO Occupancy   : %0d entries\nMaximum FIFO Occupancy   : %0d entries\nAvailable FIFO Space     : %0d entries\n--------------------------------------------------\nData Comparisons Passed  : %0d\nData Comparisons Failed  : %0d\n==================================================",
      DSIZE,
      ASIZE,
      DEPTH,
      accepted_write_count,
      blocked_write_count,
      accepted_read_count,
      blocked_read_count,
      expected_q.size(),
      max_occupancy,
      DEPTH - expected_q.size(),
      compare_pass_count,
      compare_fail_count
    ),
    UVM_NONE
  );

endfunction : report_phase

endclass : fifo_sb
