//------------------------------------------------------------------------------
// File        : fifo_tb_config_pkg.sv
// Description : Global configuration parameters for async FIFO UVM testbench.
//
// Change FIFO configuration here.
//
// All testbench components import this package, ensuring that DUT parameters,
// transaction widths, scoreboard depth, sequences, and tests use the same
// configuration values.
//------------------------------------------------------------------------------

package fifo_tb_config_pkg;

  // FIFO data width.
  parameter int DSIZE = 8;

  // FIFO address width.
  //
  // FIFO depth is 2^ASIZE.
  parameter int ASIZE = 3;

  // Derived FIFO depth.
  parameter int DEPTH = (1 << ASIZE);

endpackage : fifo_tb_config_pkg
