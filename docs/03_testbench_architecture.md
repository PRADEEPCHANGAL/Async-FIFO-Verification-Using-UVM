# Asynchronous FIFO UVM Testbench Architecture

## Document Revision History

| Version | Date | Author | Description |
|---|---|---|---|
| 0.1 | - | Pradeep Changal | Initial UVM testbench architecture based on current implementation. |

---

## 1. Overview

This document describes the current UVM testbench architecture used to verify the `async_fifo` DUT.

The asynchronous FIFO has two independent interfaces:

```text
Write domain:
    wclk, wrst_n, winc, wdata, wfull, awfull

Read domain:
    rclk, rrst_n, rinc, rdata, rempty, arempty
```

The UVM environment uses two independent agents:

```text
- fifo_write_agent
- fifo_read_agent
```

A separate write and read agent is required because the FIFO has separate write and read clock domains.


---

## 2. Testbench Architecture Diagram

 NOTE: Use Dark Theme to see diagram properly
 
<img width="1044" height="804" alt="tb drawio" src="https://github.com/user-attachments/assets/1460db9c-5fec-4f66-b05a-e0e4fb1bd0b0" />


                              

---

## 3. UVM Component Hierarchy

The implemented UVM hierarchy is:

```text
fifo_base_test
|
+-- fifo_env
    |
    +-- fifo_write_agent wagent
    |   |
    |   +-- fifo_write_sequencer wseqr
    |   +-- fifo_write_driver    wdrv
    |   +-- fifo_write_monitor   wmon
    |
    +-- fifo_read_agent ragent
    |   |
    |   +-- fifo_read_sequencer rseqr
    |   +-- fifo_read_driver    rdrv
    |   +-- fifo_read_monitor   rmon
    |
    +-- fifo_sb sb
```

The simulation top-level is outside the UVM hierarchy:

```text
fifo_tb
|
+-- async_fifo_if intf
+-- async_fifo dut
+-- fifo_base_test
```

---

## 4. Top-Level Testbench

The simulation top-level module is:

```systemverilog
module fifo_tb;
```

The top-level testbench is responsible for:

```text
- Generating write clock `wclk`
- Generating read clock `rclk`
- Instantiating `async_fifo_if`
- Instantiating the `async_fifo` DUT
- Passing the virtual interface through `uvm_config_db`
- Starting the UVM test
- Enabling VCD waveform dump
- Ending simulation through a timeout
```

---

### 4.1 Clock Generation

The current clock generation is:

```systemverilog
logic wclk = 0;
logic rclk = 0;

always #5 wclk = ~wclk;
always #7 rclk = ~rclk;
```

Current clock timing:

| Clock | Half Period | Full Period |
|---|---:|---:|
| `wclk` | 5 ns | 10 ns |
| `rclk` | 7 ns | 14 ns |

---

### 4.2 Interface Instantiation

The interface is instantiated as:

```systemverilog
async_fifo_if intf(wclk, rclk);
```

The interface provides a common connection between the DUT and UVM components.

The interface includes FIFO signals such as:

```text
Write side:
    wrst_n, winc, wdata, wfull, awfull

Read side:
    rrst_n, rinc, rdata, rempty, arempty
```

---

### 4.3 DUT Instantiation

The DUT is instantiated as:

```systemverilog
async_fifo #(DSIZE, ASIZE) dut (
    .wclk    (wclk),
    .rclk    (rclk),
    .wdata   (intf.wdata),
    .winc    (intf.winc),
    .wfull   (intf.wfull),
    .awfull  (intf.awfull),
    .rdata   (intf.rdata),
    .rinc    (intf.rinc),
    .rempty  (intf.rempty),
    .arempty (intf.arempty),
    .rrst_n  (intf.rrst_n),
    .wrst_n  (intf.wrst_n)
);
```

The currently configured DUT parameters are:

```systemverilog
parameter DSIZE = 8;
parameter ASIZE = 3;
```

Derived FIFO configuration:

```text
Data width    = 8 bits
Address width = 3 bits
FIFO depth    = 2^3 = 8 entries
```

---


## 13. Summary

The implemented UVM architecture uses a dual-agent structure appropriate for an asynchronous FIFO.

```text
Write agent:
    Drives and monitors write-side activity.

Read agent:
    Drives and monitors read-side activity.

Scoreboard:
    Receives write and read monitor transactions.
    Checks FIFO data integrity and FIFO ordering.

Coverage model:
    Planned component for measuring functional scenario coverage.
```

The testbench uses a virtual interface to connect UVM components to the DUT and uses monitor analysis ports to send observed transactions to the scoreboard.
