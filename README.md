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


## Implemented Tests

| Test ID | UVM Test Name | Description |
|---|---|---|
| `FIFO_TC_001` | `fifo_reset_test` | Verifies initial reset and runtime reset assertion/release behavior |
| `FIFO_TC_002` | `fifo_single_write_read_test` | Verifies one accepted write followed by one accepted read |
| `FIFO_TC_003` | `fifo_multiple_write_read_test` | Verifies FIFO ordering for multiple entries |
| `FIFO_TC_004` | `fifo_write_only_test` | Verifies multiple writes without reads |
| `FIFO_TC_005` | `fifo_read_only_test` | Verifies read attempts are blocked while FIFO is empty |
| `FIFO_TC_006` | `fifo_almost_full_test` | Verifies `awfull` and `wfull` boundary behavior |
| `FIFO_TC_007` | `fifo_almost_empty_test` | Verifies `arempty` and `rempty` boundary behavior |
| `FIFO_TC_008` | `fifo_fwft_test` | Verifies first-word fall-through behavior |
| `FIFO_TC_009` | `fifo_concrnt_rw_test` | Verifies concurrent read/write data integrity |
| Advanced | `fifo_clock_ratio_test` | Verifies traffic under different write/read clock ratios |

---

## Project Structure

```text
async_fifo_uvm/
|
+-- rtl/
|   +-- async_fifo.v
|   +-- fifomem.v
|   +-- sync_r2w.v
|   +-- sync_w2r.v
|   +-- wptr_full.v
|   +-- rptr_empty.v
|
+-- dv/
|   |
|   +-- interfaces/
|   |   +-- async_fifo_if.sv
|   |
|   +-- transactions/
|   |   +-- fifo_tranx.sv
|   |
|   +-- agents/
|   |   +-- fifo_sequencers.sv
|   |   +-- fifo_write_driver.sv
|   |   +-- fifo_read_driver.sv
|   |   +-- fifo_write_monitor.sv
|   |   +-- fifo_read_monitor.sv
|   |   +-- fifo_write_agent.sv
|   |   +-- fifo_read_agent.sv
|   |
|   +-- env/
|   |   +-- fifo_sb.sv
|   |   +-- fifo_coverage_model.sv
|   |   +-- fifo_env.sv
|   |
|   +-- sequences/
|   |   +-- fifo_write_sequences.sv
|   |   +-- fifo_read_sequences.sv
|   |   +-- fifo_single_write_sequences.sv
|   |   +-- fifo_single_read_sequences.sv
|   |
|   +-- tests/
|   |   +-- fifo_base_test.sv
|   |   +-- fifo_reset_test.sv
|   |   +-- fifo_single_write_read_test.sv
|   |   +-- fifo_multiple_write_read_test.sv
|   |   +-- fifo_write_only_test.sv
|   |   +-- fifo_read_only_empty_test.sv
|   |   +-- fifo_almost_full_test.sv
|   |   +-- fifo_almost_empty_test.sv
|   |   +-- fifo_fwft_test.sv
|   |   +-- fifo_concrnt_rw_test.sv
|   |   +-- fifo_clock_ratio_test.sv
|   |
|   +-- packages/
|   |   +-- fifo_tb_config_pkg.sv
|   |
|   +-- tb_top.sv
|
+-- docs/
|   +-- 01_design_specification.md
|   +-- 02_testplan.md
|   +-- 03_testbench_architecture.md
|
|
+-- scripts/
|   +-- run_regression.sh
|
+-- logs/                  # Generated during regression; ignored by Git
+-- cov/                   # Generated VCS coverage database; ignored by Git
+-- coverage_report/       # Generated URG report; ignored by Git
|
+-- README.md


---

## Simulation Requirements

- Synopsys VCS
- UVM 1.2
- URG for merged coverage reports
- Optional: GTKWave, Verdi, or DVE for waveform viewing

---

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

## Author

```text
Name: PRADEEP CHANGAL
GitHub: https://github.com/PRADEEPCHANGAL
```

---

## License

This project is licensed under the [MIT License](LICENSE). License 2.0
```
