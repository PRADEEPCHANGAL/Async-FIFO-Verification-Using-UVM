# Async-FIFO-Verification-Using-UVM


UVM-based verification environment for an asynchronous FIFO design.

This project verifies an asynchronous FIFO that transfers data between independent write and read clock domains using Gray-coded pointers and two-flop synchronizers.

---

## Features

### DUT Features

- Independent write and read clocks
- Independent active-low resets
- Parameterized data width and FIFO depth
- Gray-code pointer synchronization
- Two-flop CDC synchronizers
- Full and empty flag generation
- Almost-full and almost-empty flag generation
- First-Word Fall-Through (FWFT) read mode
- Optional registered-read mode through `FALLTHROUGH` parameter

### Verification Features

- UVM-based testbench
- Separate write and read agents
- Reusable write/read burst sequences
- Passive write and read monitors
- Queue-based reference scoreboard
- FIFO ordering and data-integrity checking
- Functional coverage model
- Configurable write/read clock ratios
- VCS regression and coverage flow
- VCD waveform generation

---

## Design Overview

The asynchronous FIFO transfers data from the write clock domain to the read clock domain.

```text
Write Clock Domain                         Read Clock Domain

wclk                                       rclk
wrst_n                                     rrst_n
winc                                       rinc
wdata                                      rdata
wfull                                      rempty
awfull                                     arempty
```

### RTL Hierarchy

```text
async_fifo
|
+-- sync_r2w
|   Synchronizes the read Gray pointer into write clock domain.
|
+-- sync_w2r
|   Synchronizes the write Gray pointer into read clock domain.
|
+-- wptr_full
|   Generates write address, Gray write pointer, wfull, and awfull.
|
+-- rptr_empty
|   Generates read address, Gray read pointer, rempty, and arempty.
|
+-- fifomem
    Dual-clock FIFO memory.
```

---

## Default Configuration

| Parameter | Default Value | Description |
|---|---:|---|
| `DSIZE` | `8` | FIFO data width |
| `ASIZE` | `3` | FIFO address width |
| `DEPTH` | `2^ASIZE = 8` | FIFO depth |
| `FALLTHROUGH` | `"TRUE"` | First-Word Fall-Through read mode |

> Change `DSIZE` and `ASIZE` from the testbench configuration package or top-level configuration, depending on project setup.

---

## FIFO Protocol

### Write Operation

A write is accepted when:

```systemverilog
write_accepted = winc && !wfull;
```

| Condition | Expected Behavior |
|---|---|
| `winc=1`, `wfull=0` | Data is written and write pointer advances |
| `winc=1`, `wfull=1` | Write is blocked and pointer does not advance |
| `winc=0` | No write operation |

### Read Operation

A read is accepted when:

```systemverilog
read_accepted = rinc && !rempty;
```

| Condition | Expected Behavior |
|---|---|
| `rinc=1`, `rempty=0` | Oldest FIFO data is consumed and read pointer advances |
| `rinc=1`, `rempty=1` | Read is blocked and pointer does not advance |
| `rinc=0` | No read operation |

---

## First-Word Fall-Through Behavior

The default configuration uses:

```verilog
FALLTHROUGH = "TRUE"
```

The FIFO read path is:

```verilog
assign rdata = mem[raddr];
```

Therefore:

```text
- When FIFO is non-empty, rdata shows the oldest unread entry.
- Data can be visible before rinc is asserted.
- A legal read consumes the currently visible word.
- rdata is invalid / don't-care while rempty=1.
```

---

## UVM Testbench Architecture

```text
fifo_tb
|
+-- async_fifo_if
|
+-- async_fifo DUT
|
+-- fifo_base_test
    |
    +-- fifo_env
        |
        +-- fifo_write_agent
        |   |
        |   +-- fifo_write_sequencer
        |   +-- fifo_write_driver
        |   +-- fifo_write_monitor
        |
        +-- fifo_read_agent
        |   |
        |   +-- fifo_read_sequencer
        |   +-- fifo_read_driver
        |   +-- fifo_read_monitor
        |
        +-- fifo_sb
        |
        +-- fifo_coverage_model
```

### Data Flow

```text
Write Sequence
    |
    v
Write Driver --> DUT --> Write Monitor --> Scoreboard / Coverage

Read Sequence
    |
    v
Read Driver  --> DUT --> Read Monitor  --> Scoreboard / Coverage
```

---

## Scoreboard

The scoreboard implements a reference FIFO using a SystemVerilog queue.

```systemverilog
bit [DSIZE-1:0] expected_q[$];
```

### Scoreboard Behavior

```text
Accepted Write:
    expected_q.push_back(wdata)

Accepted Read:
    expected_data = expected_q.pop_front()
    compare expected_data with DUT rdata
```

The scoreboard detects:

- Data corruption
- Data loss
- Data duplication
- Data reordering
- Reference-model underflow
- Blocked write attempts
- Blocked read attempts

---

## Implemented Tests

| Test ID | UVM Test Name | Description |
|---|---|---|
| `FIFO_TC_001` | `fifo_reset_test` | Verifies initial reset and runtime reset assertion/release behavior |
| `FIFO_TC_002` | `fifo_single_write_read_test` | Verifies one accepted write followed by one accepted read |
| `FIFO_TC_003` | `fifo_multiple_write_read_test` | Verifies FIFO ordering for multiple entries |
| `FIFO_TC_004` | `fifo_write_only_test` | Verifies multiple writes without reads |
| `FIFO_TC_005` | `fifo_read_only_empty_test` | Verifies read attempts are blocked while FIFO is empty |
| `FIFO_TC_010` | `fifo_almost_full_test` | Verifies `awfull` and `wfull` boundary behavior |
| `FIFO_TC_011` | `fifo_almost_empty_test` | Verifies `arempty` and `rempty` boundary behavior |
| `FIFO_TC_012` | `fifo_fwft_test` | Verifies first-word fall-through behavior |
| `FIFO_TC_013` | `fifo_concurrent_rw_test` | Verifies concurrent read/write data integrity |
| Advanced | `fifo_clock_ratio_test` | Verifies traffic under different write/read clock ratios |

---

## Functional Coverage

The functional coverage model collects protocol-level coverage for:

### Write Side

- Accepted writes
- Blocked writes while full
- `wfull` state during write attempts
- `awfull` state during write attempts
- Write-result × full-state cross coverage

### Read Side

- Accepted reads
- Blocked reads while empty
- `rempty` state during read attempts
- `arempty` state during read attempts
- Read-result × empty-state cross coverage

---

## Project Structure

```text
async-fifo-uvm/
|
+-- rtl/
|   +-- async_fifo.v
|   +-- fifomem.v
|   +-- sync_r2w.v
|   +-- sync_w2r.v
|   +-- wptr_full.v
|   +-- rptr_empty.v
|
+-- tb/
|   +-- async_fifo_if.sv
|   +-- fifo_transaction.sv
|   +-- fifo_write_driver.sv
|   +-- fifo_read_driver.sv
|   +-- fifo_write_monitor.sv
|   +-- fifo_read_monitor.sv
|   +-- fifo_write_agent.sv
|   +-- fifo_read_agent.sv
|   +-- fifo_sb.sv
|   +-- fifo_coverage_model.sv
|   +-- fifo_env.sv
|   +-- sequences/
|   +-- tests/
|   +-- fifo_tb.sv
|
+-- docs/
|   +-- 01_design_specification.md
|   +-- 02_testplan.md
|   +-- 03_testbench_architecture.md
|
+-- scripts/
|   +-- run_regression.sh
|
+-- sim.f
+-- README.md
```

---

## Simulation Requirements

- Synopsys VCS
- UVM 1.2
- URG for merged coverage reports
- Optional: GTKWave, Verdi, or DVE for waveform viewing

---

## Compile

Compile the RTL and UVM testbench with functional and RTL code coverage enabled.

```bash
vcs -full64 -sverilog \
    -ntb_opts uvm-1.2 \
    -f sim.f \
    -cm line+cond+branch+tgl+fcover \
    -cm_dir cov/async_fifo.vdb \
    -l compile.log \
    -o simv
```

---

## Run a Single Test

Example: run the single write/read test.

```bash
./simv \
  +UVM_TESTNAME=fifo_single_write_read_test \
  -cm_dir cov/async_fifo.vdb \
  -cm_name fifo_single_write_read_test \
  | tee logs/fifo_single_write_read_test.log
```

Check for errors:

```bash
grep -nE "UVM_ERROR|UVM_FATAL" \
  logs/fifo_single_write_read_test.log
```

View scoreboard summary:

```bash
grep -A 15 "FIFO SCOREBOARD SUMMARY" \
  logs/fifo_single_write_read_test.log
```

---

## Run Regression

Make the regression script executable:

```bash
chmod +x scripts/run_regression.sh
```

Run all configured tests:

```bash
./scripts/run_regression.sh
```

The script creates:

```text
logs/
    Individual simulation log for each test.

cov/
    VCS coverage database.

coverage_report/
    Merged URG coverage report.
```

---

## Run Clock-Ratio Test

### Write Faster Than Read

```bash
./simv \
  +UVM_TESTNAME=fifo_clock_ratio_test \
  +WCLK_HALF_NS=2 \
  +RCLK_HALF_NS=10
```

### Read Faster Than Write

```bash
./simv \
  +UVM_TESTNAME=fifo_clock_ratio_test \
  +WCLK_HALF_NS=10 \
  +RCLK_HALF_NS=2
```

### Asynchronous Ratio

```bash
./simv \
  +UVM_TESTNAME=fifo_clock_ratio_test \
  +WCLK_HALF_NS=5 \
  +RCLK_HALF_NS=8
```

---

## Generate Coverage Report

After regression:

```bash
urg \
  -dir cov/async_fifo.vdb \
  -metric line+cond+branch+tgl+fcover \
  -report coverage_report
```

Open the generated HTML report:

```bash
firefox coverage_report/dashboard.html &
```

If `dashboard.html` is unavailable:

```bash
firefox coverage_report/index.html &
```

---

## Waveform Generation

The testbench generates a VCD waveform file.

```text
async_fifo_uvm.vcd
```

Open using GTKWave:

```bash
gtkwave async_fifo_uvm.vcd
```

Useful signals to inspect:

```text
wclk
rclk
wrst_n
rrst_n
winc
wdata
wfull
awfull
rinc
rdata
rempty
arempty
wptr
rptr
wq2_rptr
rq2_wptr
```

---

## Key Learning Points

This project demonstrates:

- Asynchronous FIFO architecture
- Gray-code pointer generation
- Two-flop pointer synchronization
- Full and empty detection
- First-word fall-through FIFO behavior
- UVM agents, drivers, monitors, sequencers, and scoreboards
- Analysis ports and analysis exports
- Queue-based reference models
- Functional coverage
- VCS regression execution
- Code coverage and functional coverage reporting

---

## Future Improvements

- Write-when-full test
- Full recovery after read test
- Empty recovery after write test
- Pointer wraparound stress test
- Constrained-random read/write sequences
- Midstream reset test with active traffic
- Separate write/read reset testing
- Registered-read mode verification with `FALLTHROUGH="FALSE"`
- Assertion-based verification using SVA
- Parameterized regression for multiple `DSIZE` and `ASIZE` values

---

## Author

Add your name and GitHub profile here.

```text
Name: <Your Name>
GitHub: https://github.com/<your-github-username>
```

---

## License

Add a license file if you plan to make the repository public.

Recommended options:

```text
MIT License
Apache License 2.0
```
