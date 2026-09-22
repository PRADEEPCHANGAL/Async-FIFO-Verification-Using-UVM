# Asynchronous FIFO Design Specification

## Document Revision History

| Version | Date | Author | Description |
|---|---|---|---|
| 0.1 | TBD | TBD | Initial detailed test specifications. |

---

## 1. Overview

This document describes the functional behavior and architecture of the `async_fifo` RTL design.

The design is an **asynchronous FIFO (First-In First-Out) buffer** that transfers data between two independent clock domains:

- Write clock domain: `wclk`
- Read clock domain: `rclk`

The FIFO supports:

- Independent write and read clocks
- Independent active-low resets
- Gray-code pointer synchronization across clock domains
- Full and empty detection
- Almost-full and almost-empty indications
- Configurable data width
- Configurable FIFO depth
- Optional first-word fall-through read behavior

The design uses a dual-clock memory and synchronized Gray-code pointers to safely determine FIFO status across unrelated clock domains.

---

## 2. RTL Hierarchy

The top-level module is:
```text
async_fifo
|
+-- sync_r2w
|   Synchronizes the read pointer from the read clock domain
|   into the write clock domain.
|
+-- sync_w2r
|   Synchronizes the write pointer from the write clock domain
|   into the read clock domain.
|
+-- wptr_full
|   Maintains write pointers and generates:
|   - Write memory address
|   - Gray-code write pointer
|   - Full flag
|   - Almost-full flag
|
+-- rptr_empty
|   Maintains read pointers and generates:
|   - Read memory address
|   - Gray-code read pointer
|   - Empty flag
|   - Almost-empty flag
|
+-- fifomem
    Dual-clock FIFO storage memory.
    - Written in the write clock domain
    - Read in the read clock domain
```
---

## 3. Parameters
The top-level FIFO parameters are:
```text
parameter DSIZE = 8,
parameter ASIZE = 4,
parameter FALLTHROUGH = "TRUE"
```
DSIZE specifies the width of each FIFO data word.

ASIZE specifies the number of address bits used for FIFO memory addressing.
```text
FIFO depth is calculated as:
DEPTH = 2^ASIZE
ASIZE = 4
DEPTH = 2^4 = 16 entries
```
FALLTHROUGH controls read-data behavior.

```text
"TRUE"  : First-word fall-through / combinational read mode
"FALSE" : Registered / synchronous read mode
```
---

## 4. External Interface
Write Clock Domain Interface:-
```text
| Signal| Direction | Description |
|---|---|---|---|
| `wclk`             | Input     | Write-domain clock |
| `wrst_n`           | Input     | Active-low asynchronous write-domain reset |
| `winc`             | Input     | Write request/increment signal |
| `wdata[DSIZE-1:0]` | Input     | Data to be written into FIFO |
| `wfull`            | Output    | FIFO full status in the write clock domain |
| `awfull`           | Output    | FIFO almost-full status in the write clock domain |
```
Read Clock Domain Interface:-
```text
| Signal             | Direction | Description |
|---|---|---|---|
| `rclk`             | Input     | Read-domain clock |
| `rrst_n`           | Input     | Active-low asynchronous read-domain reset |
| `rinc`             | Input     | Read request/increment signal |
| `rdata[DSIZE-1:0]` | Output    | Data output from FIFO |
| `rempty`           | Output    | FIFO empty status in the read clock domain |
| `arempty`          | Output    | FIFO almost-empty status in the read clock domain |
```
---
## 5. Clocking Model

The FIFO has two independent clock domains:
```text
**Write Domain:**
    Clock : wclk
    Reset : wrst_n

**Read Domain:**
    Clock : rclk
    Reset : rrst_n
```
There is no requirement in the RTL that wclk and rclk have:
The same frequency
A fixed frequency ratio
A fixed phase relationship
Simultaneous edges
---

## 6. Reset Behavior

The design has independent active-low asynchronous resets:
```text
wrst_n
rrst_n
```
---

## 7. Pointer Architecture

The FIFO uses separate read and write pointers.

Each pointer has two representations:
```text
Memory address width = ASIZE
Pointer width        = ASIZE + 1
```
Binary pointer:
    Used locally to generate the memory address.

Gray-code pointer:
    Used for safe synchronization across clock domains.
    
For the default configuration:
```text
ASIZE = 4
Address width = 4 bits
Pointer width = 5 bits
FIFO depth = 16 entries
```
**Write Pointer**
The write-side module wptr_full maintains:
reg  [ADDRSIZE:0] wbin;
output reg [ADDRSIZE:0] wptr;

The write memory address is generated from the lower binary pointer bits:
assign waddr = wbin[ADDRSIZE-1:0];
The upper pointer bit is not part of the RAM address. It tracks pointer wraparound.

**Read Pointer**
The read-side module rptr_empty maintains:
reg  [ADDRSIZE:0] rbin;
output reg [ADDRSIZE:0] rptr;

The read memory address is generated from the lower binary pointer bits:
assign raddr = rbin[ADDRSIZE-1:0];
The upper pointer bit tracks wraparound.

**Pointer Wraparound**
For a FIFO with:
ASIZE = 4
DEPTH = 16
The memory address range is:
0 through 15
After 16 accepted writes, the binary write address wraps:
waddr: 15 -> 0
However, the full binary write pointer does not return to its original value because it includes the additional wrap bit.
Before wrap:
    wbin = 0_1111
    waddr = 1111 = 15

After one accepted write:
    wbin = 1_0000
    waddr = 0000 = 0

0_0000 : Initial pointer position
1_0000 : Same memory address after one complete FIFO wrap

This distinction is required for correct full and empty detection.
---
## 8. Clock-Domain Crossing Synchronization

Read Pointer Synchronization into Write Domain, The read pointer is generated in the read clock domain but is required by the write-side full-detection logic.
```text
rptr
  |
  | asynchronous crossing
  v
wq1_rptr
  |
  | one wclk cycle later
  v
wq2_rptr
```
wq2_rptr is the synchronized read pointer used in the write domain.

Write Pointer Synchronization into Read Domain, The write pointer is generated in the write clock domain but is required by the read-side empty-detection.
```text
wptr
  |
  | asynchronous crossing
  v
rq1_wptr
  |
  | one rclk cycle later
  v
rq2_wptr
```
rq2_wptr is the synchronized write pointer used in the read domain.

**Synchronization Latency**
The remote pointer is visible after passing through two destination-clock-domain registers. Therefore, status flags are conservative and have synchronization latency.
Write to Read Visibility
After a legal write:
1. Data is written on a wclk edge.
2. The write pointer advances in the write domain.
3. The write pointer enters the read-domain synchronizer.
4. rq1_wptr captures the pointer on an rclk edge.
5. rq2_wptr captures the pointer on a later rclk edge.
6. The read-side empty logic observes rq2_wptr.
7. rempty may deassert.

As a result: A newly written entry may not become readable until two or more rclk cycles after the write.

Read to Write Visibility
After a legal read:
1. The read pointer advances on an rclk edge.
2. The read pointer enters the write-domain synchronizer.
3. wq1_rptr captures the pointer on a wclk edge.
4. wq2_rptr captures the pointer on a later wclk edge.
5. The write-side full logic observes wq2_rptr.
6. wfull may deassert.

As a result: Space created by a read may not become writable until two or more wclk cycles after the read.






