//------------------------------------------------------------------------------
// File        : fifo_coverage_model.sv
// Description : Functional coverage model for asynchronous FIFO.
//
// The coverage model receives transactions from:
//
//   fifo_write_monitor --> cm_export_write
//   fifo_read_monitor  --> cm_export_read
//
// It does not drive DUT signals and does not perform data comparison.
// Data integrity and FIFO ordering are checked by fifo_sb.
//
// Coverage targets:
//
// Write side:
//   - Write request
//   - Accepted write
//   - Blocked write while full
//   - wfull and awfull states
//
// Read side:
//   - Read request
//   - Accepted read
//   - Blocked read while empty
//   - rempty and arempty states
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Create separate analysis implementation types for coverage model.
//
// These macros create:
//
//   uvm_analysis_imp_cov_w --> write_cov_w()
//   uvm_analysis_imp_cov_r --> write_cov_r()
//------------------------------------------------------------------------------
`uvm_analysis_imp_decl(_cov_w)
`uvm_analysis_imp_decl(_cov_r)


class fifo_coverage_model extends uvm_component;

  `uvm_component_utils(fifo_coverage_model)

  //--------------------------------------------------------------------------
  // Analysis exports
  //
  // Write monitor connects to cm_export_write.
  // Read monitor connects to cm_export_read.
  //--------------------------------------------------------------------------

  uvm_analysis_imp_cov_w #(fifo_transaction, fifo_coverage_model)
    cm_export_write;

  uvm_analysis_imp_cov_r #(fifo_transaction, fifo_coverage_model)
    cm_export_read;

  //--------------------------------------------------------------------------
  // Sample variables
  //
  // The covergroups sample these local variables. The analysis callbacks copy
  // transaction fields into these variables and then call sample().
  //--------------------------------------------------------------------------

  // Write-side sampled fields
  bit cov_winc;
  bit cov_wfull;
  bit cov_awfull;
  bit cov_write_accepted;

  // Read-side sampled fields
  bit cov_rinc;
  bit cov_rempty;
  bit cov_arempty;
  bit cov_read_accepted;

  //--------------------------------------------------------------------------
  // Write-Side Covergroup
  //--------------------------------------------------------------------------

  covergroup write_cg;

    option.per_instance = 1;
    option.name         = "write_cg";

    // Write request is expected to be high because monitor publishes only
    // write attempts. Keeping this coverpoint is still useful for debug.
    cp_winc: coverpoint cov_winc {
      ignore_bins no_write_request = {0};
      bins write_request    = {1};
    }

    // Full flag values seen at write attempts.
    cp_wfull: coverpoint cov_wfull {
      bins not_full = {0};
      bins full     = {1};
    }

    // Almost-full flag values seen at write attempts.
    cp_awfull: coverpoint cov_awfull {
      bins not_almost_full = {0};
      bins almost_full     = {1};
    }

    // Accepted versus blocked write attempts.
    cp_write_accepted: coverpoint cov_write_accepted {
      bins accepted = {1};
      bins blocked  = {0};
    }

    // Main write-protocol coverage:
    //
    // winc=1  -> accepted write
    // winc=1  -> blocked write
    cross_write_full: cross cp_winc, cp_write_accepted;

    // Check write attempts around almost-full boundary.
    cross_write_awfull: cross cp_winc, cp_awfull;

  endgroup : write_cg


  //--------------------------------------------------------------------------
  // Read-Side Covergroup
  //--------------------------------------------------------------------------

  covergroup read_cg;

    option.per_instance = 1;
    option.name         = "read_cg";

    // Read request is expected to be high because monitor publishes only
    // read attempts.
    cp_rinc: coverpoint cov_rinc {
      ignore_bins no_read_request = {0};
      bins read_request    = {1};
    }

    // Empty flag values seen at read attempts.
    cp_rempty: coverpoint cov_rempty {
      bins not_empty = {0};
      bins empty     = {1};
    }

    // Almost-empty flag values seen at read attempts.
    cp_arempty: coverpoint cov_arempty {
      bins not_almost_empty = {0};
      bins almost_empty     = {1};
    }

    // Accepted versus blocked read attempts.
    cp_read_accepted: coverpoint cov_read_accepted {
      bins accepted = {1};
      bins blocked  = {0};
    }

    // Main read-protocol coverage:
    //
    // rinc=1  -> accepted read
    // rinc=1  -> blocked read
    cross_read_empty: cross cp_rinc, cp_read_accepted;

    // Check read attempts around almost-empty boundary.
    cross_read_arempty: cross cp_rinc, cp_arempty;

  endgroup : read_cg


  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(
    string name = "fifo_coverage_model",
    uvm_component parent = null
  );
    super.new(name, parent);

    // Construct covergroups.
    write_cg = new();
    read_cg  = new();
  endfunction


  //--------------------------------------------------------------------------
  // build_phase
  //
  // Create analysis implementation exports.
  //--------------------------------------------------------------------------

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cm_export_write = new("cm_export_write", this);
    cm_export_read  = new("cm_export_read", this);
  endfunction


  //--------------------------------------------------------------------------
  // write_cov_w
  //
  // Called when write monitor publishes a write-attempt transaction.
  //--------------------------------------------------------------------------

  function void write_cov_w(fifo_transaction trans);

    // Copy transaction data into covergroup sample variables.
    cov_winc           = trans.winc;
    cov_wfull          = trans.wfull;
    cov_awfull         = trans.awfull;
    cov_write_accepted = trans.write_accepted;

    // Sample write-side coverage.
    write_cg.sample();

    `uvm_info(
      "FIFO_COVERAGE",
      $sformatf(
        "Sampled write coverage | winc=%0b wfull=%0b awfull=%0b accepted=%0b",
        cov_winc,
        cov_wfull,
        cov_awfull,
        cov_write_accepted
      ),
      UVM_HIGH
    )

  endfunction : write_cov_w


  //--------------------------------------------------------------------------
  // write_cov_r
  //
  // Called when read monitor publishes a read-attempt transaction.
  //--------------------------------------------------------------------------

  function void write_cov_r(fifo_transaction trans);

    // Copy transaction data into covergroup sample variables.
    cov_rinc          = trans.rinc;
    cov_rempty        = trans.rempty;
    cov_arempty       = trans.arempty;
    cov_read_accepted = trans.read_accepted;

    // Sample read-side coverage.
    read_cg.sample();

    `uvm_info(
      "FIFO_COVERAGE",
      $sformatf(
        "Sampled read coverage | rinc=%0b rempty=%0b arempty=%0b accepted=%0b",
        cov_rinc,
        cov_rempty,
        cov_arempty,
        cov_read_accepted
      ),
      UVM_HIGH
    )

  endfunction : write_cov_r


//------------------------------------------------------------------------------
// report_phase
//
// Print final functional coverage percentage.
//------------------------------------------------------------------------------
function void report_phase(uvm_phase phase);

  real write_coverage;
  real read_coverage;
  real total_coverage;

  super.report_phase(phase);

  // Get individual covergroup coverage.
  write_coverage = write_cg.get_coverage();
  read_coverage  = read_cg.get_coverage();

  // Simple average of write and read coverage.
  //
  // Note:
  // This is only a reporting convenience. In a professional regression,
  // coverage tools normally merge and report coverage databases directly.
  total_coverage = (write_coverage + read_coverage) / 2.0;

  `uvm_info(
    "FIFO_COVERAGE_SUMMARY",
    $sformatf(
      "==================================================\nFunctional Coverage Summary\n==================================================\nWrite Coverage : %0.2f%%\nRead Coverage  : %0.2f%%\nAverage Coverage : %0.2f%%\n==================================================",
      write_coverage,
      read_coverage,
      total_coverage
    ),
    UVM_NONE
  )

endfunction : report_phase

endclass : fifo_coverage_model
