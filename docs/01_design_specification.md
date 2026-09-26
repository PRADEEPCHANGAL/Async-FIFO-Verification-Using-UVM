# Asynchronous FIFO Design Specification

## Document Revision History

| Version | Date | Author | Description |
|---|---|---|---|
| 0.1 | TBD | Pradeep Changal | Initial detailed test specifications. |

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
### 4.1 Write Clock Domain Interface

| Signal | Direction | Description |
|---|---|---|
| `wclk` | Input | Write-domain clock |
| `wrst_n` | Input | Active-low asynchronous write-domain reset |
| `winc` | Input | Write request/increment signal |
| `wdata[DSIZE-1:0]` | Input | Data to be written into FIFO |
| `wfull` | Output | FIFO full status in the write clock domain |
| `awfull` | Output | FIFO almost-full status in the write clock domain |
### 4.2 Read Clock Domain Interface

| Signal | Direction | Description |
|---|---|---|
| `rclk` | Input | Read-domain clock |
| `rrst_n` | Input | Active-low asynchronous read-domain reset |
| `rinc` | Input | Read request/increment signal |
| `rdata[DSIZE-1:0]` | Output | Data output from FIFO |
| `rempty` | Output | FIFO empty status in the read clock domain |
| `arempty` | Output | FIFO almost-empty status in the read clock domain |
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
The same frequency,
A fixed frequency ratio,
A fixed phase relationship,
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

---

## 9. FIFO Memory and Storage Behavior

FIFO data storage is implemented in the `fifomem` module.

```verilog
module fifomem
#(
    parameter DATASIZE = 8,
    parameter ADDRSIZE = 4,
    parameter FALLTHROUGH = "TRUE"
);
```

The memory depth is derived from the address width:

```text
DEPTH = 2^ADDRSIZE
```

For the default FIFO configuration:

```text
DATASIZE = 8 bits
ADDRSIZE = 4 bits
DEPTH    = 16 entries
```

The internal storage array is declared as:

```verilog
reg [DATASIZE-1:0] mem [0:DEPTH-1];
```

For default parameters, the memory is equivalent to:

```verilog
reg [7:0] mem [0:15];
```

---

### 9.1 Write Memory Port

The FIFO memory write port operates in the write clock domain.

```verilog
always @(posedge wclk) begin
    if (wclken && !wfull)
        mem[waddr] <= wdata;
end
```

At the top-level FIFO, the write enable is connected as:

```verilog
.wclken(winc)
```

Therefore, an actual memory write occurs only when:

```systemverilog
write_accepted = winc && !wfull;
```

For every accepted write:

```text
1. `wdata` is written to `mem[waddr]`.
2. The write pointer advances.
3. The write address advances for the next accepted write.
```

When the FIFO is full:

```systemverilog
winc && wfull
```

no memory write occurs.

```text
- The current memory content is preserved.
- No unread entry is overwritten.
- The write pointer does not advance.
```

---

### 9.2 Read Memory Port

The FIFO memory read port uses:

```text
Read clock : rclk
Read enable: rclken
Read address: raddr
Read data  : rdata
```

The detailed behavior depends on the `FALLTHROUGH` parameter.

---

### 9.3 First-Word Fall-Through Read Mode

The default FIFO configuration is:

```verilog
FALLTHROUGH = "TRUE"
```

In fall-through mode, the RTL read-data path is:

```verilog
assign rdata = mem[raddr];
```

This is a combinational memory read.

When the FIFO is non-empty:

```text
- `raddr` points to the oldest unread FIFO entry.
- `rdata` reflects the data stored at `mem[raddr]`.
- The front FIFO data can be visible before `rinc` is asserted.
```

A read request does not directly enable `rdata` in fall-through mode. Instead, a valid read request advances the read pointer:

```systemverilog
read_accepted = rinc && !rempty;
```

After an accepted read:

```text
1. The read pointer advances on `posedge rclk`.
2. `raddr` updates to the next FIFO location.
3. `rdata` may change to reflect the next unread FIFO entry.
```

---

### 9.4 Registered Read Mode

When:

```verilog
FALLTHROUGH = "FALSE"
```

the FIFO uses a registered read-data path:

```verilog
always @(posedge rclk) begin
    if (rclken)
        rdata_r <= mem[raddr];
end

assign rdata = rdata_r;
```

In this mode:

```text
- `rdata` updates only on `posedge rclk`.
- `rclken` must be asserted to capture memory data.
- Read data has clocked latency.
```

The baseline verification configuration uses:

```verilog
FALLTHROUGH = "TRUE"
```

Verification of registered-read mode is planned as a separate parameterized test.

---

### 9.5 Memory Reset Behavior

The `fifomem` module does not have a reset input.

```text
Memory entries are not explicitly cleared during `wrst_n` or `rrst_n`.
```

Therefore, after reset:

```text
- Memory contents may be unknown in simulation.
- Memory contents may retain old values in hardware or simulation.
- `rdata` must not be treated as valid while `rempty=1`.
```

The FIFO reset behavior is controlled by resetting pointers and status flags, not by clearing the memory array.

The read-side reset state is:

```text
rempty  = 1
arempty = 0
```

The write-side reset state is:

```text
wfull  = 0
awfull = 0
```

---

### 9.6 Read Data Validity

For the baseline fall-through configuration, `rdata` is considered valid only when:

```systemverilog
rempty == 1'b0;
```

The consumer should use `rdata` only when FIFO data is available.

A data word is considered consumed only when:

```systemverilog
rinc && !rempty;
```

When:

```systemverilog
rempty == 1'b1;
```

the value of `rdata` is unspecified and shall not be checked for functional correctness.

---

### 9.7 Memory Access Summary

| Operation | Condition | Clock Domain | Expected Behavior |
|---|---|---|---|
| Accepted write | `winc && !wfull` | `wclk` | `wdata` is written to `mem[waddr]`. |
| Blocked write | `winc && wfull` | `wclk` | Memory is not modified. |
| FWFT data visibility | `rempty == 0` | Read interface | `rdata` reflects `mem[raddr]`. |
| Accepted read | `rinc && !rempty` | `rclk` | Current front item is consumed and `raddr` advances. |
| Blocked read | `rinc && rempty` | `rclk` | Read pointer does not advance; `rdata` is not valid for checking. |

---

## 10. Write-Side Functional Behavior

Write-side control logic is implemented in the `wptr_full` module.

This module operates in the write clock domain and generates:

- Write memory address: `waddr`
- Gray-coded write pointer: `wptr`
- FIFO full flag: `wfull`
- FIFO almost-full flag: `awfull`

---

### 10.1 Write-Side Signals

| Signal | Direction | Description |
|---|---|---|
| `wclk` | Input | Write-domain clock. |
| `wrst_n` | Input | Active-low asynchronous write-domain reset. |
| `winc` | Input | Write request signal. |
| `wq2_rptr` | Input | Read Gray pointer synchronized into the write domain. |
| `waddr` | Output | Binary memory address for the current write operation. |
| `wptr` | Output | Gray-coded write pointer sent to the read domain. |
| `wfull` | Output | Indicates that no additional write may be accepted. |
| `awfull` | Output | Indicates that one writable FIFO location remains. |

---

### 10.2 Write Acceptance Condition

A write request is accepted only when the FIFO is not full.

```systemverilog
write_accepted = winc && !wfull;
```

The write pointer update logic is:

```verilog
assign wbinnext = wbin + (winc & ~wfull);
```

Therefore:

| `winc` | `wfull` | Write Accepted | Expected Behavior |
|---:|---:|---:|---|
| `0` | `0` | `0` | No write occurs; write pointer does not advance. |
| `0` | `1` | `0` | No write occurs; write pointer does not advance. |
| `1` | `0` | `1` | `wdata` is written and write pointer advances. |
| `1` | `1` | `0` | Write is blocked; no memory write or pointer advance occurs. |

---

### 10.3 Write Pointer Operation

The write-side control logic maintains two forms of the write pointer:

```verilog
reg [ADDRSIZE:0] wbin;
reg [ADDRSIZE:0] wptr;
```

| Pointer | Representation | Purpose |
|---|---|---|
| `wbin` | Binary | Used locally to generate the memory write address. |
| `wptr` | Gray code | Synchronized into the read clock domain for empty detection. |

The next binary pointer is calculated as:

```verilog
assign wbinnext = wbin + (winc & ~wfull);
```

The next Gray-coded pointer is calculated as:

```verilog
assign wgraynext = (wbinnext >> 1) ^ wbinnext;
```

Both pointers update on the rising edge of `wclk`.

```verilog
always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
        {wbin, wptr} <= 0;
    else
        {wbin, wptr} <= {wbinnext, wgraynext};
end
```

---

### 10.4 Write Address Generation

The memory write address is generated from the lower bits of the binary write pointer.

```verilog
assign waddr = wbin[ADDRSIZE-1:0];
```

For the default configuration:

```text
ASIZE = 4
DEPTH = 16
```

the write address is:

```text
waddr = wbin[3:0]
```

The additional most-significant bit in `wbin` is not used for memory addressing. It tracks pointer wraparound for full detection.

For an accepted write:

```text
1. The current `waddr` selects the memory location to be written.
2. `wdata` is stored at that address on `posedge wclk`.
3. The write pointer increments for the next accepted write.
4. `waddr` changes to the next memory location.
```

---

### 10.5 Full Flag Behavior

The full flag is calculated using the next Gray-coded write pointer and the synchronized Gray-coded read pointer.

```verilog
assign wfull_val =
    (wgraynext ==
     {~wq2_rptr[ADDRSIZE:ADDRSIZE-1],
       wq2_rptr[ADDRSIZE-2:0]});
```

The full flag updates on the rising edge of `wclk`.

```verilog
always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
        wfull <= 1'b0;
    else
        wfull <= wfull_val;
end
```

`wfull` indicates that the FIFO has no writable locations available from the write-domain point of view.

When:

```systemverilog
wfull == 1'b1;
```

the write-side interface shall not accept additional writes.

---

### 10.6 Almost-Full Flag Behavior

The almost-full flag is calculated by checking whether one additional accepted write after the next pointer position would make the FIFO full.

```verilog
assign wgraynextp1 =
    ((wbinnext + 1'b1) >> 1) ^ (wbinnext + 1'b1);

assign awfull_val =
    (wgraynextp1 ==
     {~wq2_rptr[ADDRSIZE:ADDRSIZE-1],
       wq2_rptr[ADDRSIZE-2:0]});
```

The almost-full flag updates on the rising edge of `wclk`.

```verilog
always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
        awfull <= 1'b0;
    else
        awfull <= awfull_val;
end
```

For this RTL implementation:

```text
awfull = 1 indicates that one writable FIFO entry remains.
wfull  = 1 indicates that no writable FIFO entry remains.
```

For the default FIFO depth of 16:

| Write-Domain Visible Occupancy | `awfull` | `wfull` |
|---:|---:|---:|
| 0 to 14 entries | `0` | `0` |
| 15 entries | `1` | `0` |
| 16 entries | Not used for write acceptance | `1` |

> `awfull` is an advisory status flag. `wfull` is the controlling flag that blocks writes.

---

### 10.7 Write Reset Behavior

When the write reset is asserted:

```verilog
wrst_n == 1'b0;
```

the write-side state is reset asynchronously.

```verilog
{wbin, wptr} <= 0;
wfull         <= 1'b0;
awfull        <= 1'b0;
```

Expected write-side reset state:

| Signal | Reset Value |
|---|---:|
| `wbin` | `0` |
| `wptr` | `0` |
| `wfull` | `0` |
| `awfull` | `0` |

After write reset, the write side considers the FIFO writable because:

```text
wfull = 0
```

---

## 11. Read-Side Functional Behavior

Read-side control logic is implemented in the `rptr_empty` module.

This module operates in the read clock domain and generates:

- Read memory address: `raddr`
- Gray-coded read pointer: `rptr`
- FIFO empty flag: `rempty`
- FIFO almost-empty flag: `arempty`

---

### 11.1 Read-Side Signals

| Signal | Direction | Description |
|---|---|---|
| `rclk` | Input | Read-domain clock. |
| `rrst_n` | Input | Active-low asynchronous read-domain reset. |
| `rinc` | Input | Read request signal. |
| `rq2_wptr` | Input | Write Gray pointer synchronized into the read domain. |
| `raddr` | Output | Binary memory address of the current FIFO front entry. |
| `rptr` | Output | Gray-coded read pointer sent to the write domain. |
| `rempty` | Output | Indicates that no readable FIFO entry is available. |
| `arempty` | Output | Indicates that one readable FIFO entry remains. |

---

### 11.2 Read Acceptance Condition

A read request is accepted only when the FIFO is not empty.

```systemverilog
read_accepted = rinc && !rempty;
```

The read pointer update logic is:

```verilog
assign rbinnext = rbin + (rinc & ~rempty);
```

Therefore:

| `rinc` | `rempty` | Read Accepted | Expected Behavior |
|---:|---:|---:|---|
| `0` | `0` | `0` | No read occurs; read pointer does not advance. |
| `0` | `1` | `0` | No read occurs; read pointer does not advance. |
| `1` | `0` | `1` | Current front item is consumed and read pointer advances. |
| `1` | `1` | `0` | Read is blocked; read pointer does not advance. |

---

### 11.3 Read Pointer Operation

The read-side control logic maintains two forms of the read pointer:

```verilog
reg [ADDRSIZE:0] rbin;
reg [ADDRSIZE:0] rptr;
```

| Pointer | Representation | Purpose |
|---|---|---|
| `rbin` | Binary | Used locally to generate the memory read address. |
| `rptr` | Gray code | Synchronized into the write clock domain for full detection. |

The next binary pointer is calculated as:

```verilog
assign rbinnext = rbin + (rinc & ~rempty);
```

The next Gray-coded pointer is calculated as:

```verilog
assign rgraynext = (rbinnext >> 1) ^ rbinnext;
```

Both pointers update on the rising edge of `rclk`.

```verilog
always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
        {rbin, rptr} <= 0;
    else
        {rbin, rptr} <= {rbinnext, rgraynext};
end
```

---

### 11.4 Read Address Generation

The memory read address is generated from the lower bits of the binary read pointer.

```verilog
assign raddr = rbin[ADDRSIZE-1:0];
```

For the default configuration:

```text
ASIZE = 4
DEPTH = 16
```

the read address is:

```text
raddr = rbin[3:0]
```

The extra most-significant bit in `rbin` is not used as a memory address bit. It tracks pointer wraparound for empty detection.

For an accepted read:

```text
1. `rdata` represents the data at the current `raddr`.
2. The current front FIFO entry is consumed on `posedge rclk`.
3. The read pointer increments.
4. `raddr` changes to the next FIFO memory location.
5. In fall-through mode, `rdata` can change to the next front entry.
```

---

### 11.5 Empty Flag Behavior

The empty flag is calculated by comparing the next Gray-coded read pointer with the synchronized Gray-coded write pointer.

```verilog
assign rempty_val = (rgraynext == rq2_wptr);
```

The empty flag updates on the rising edge of `rclk`.

```verilog
always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
        rempty <= 1'b1;
    else
        rempty <= rempty_val;
end
```

`rempty` indicates that no readable FIFO data is available from the read-domain point of view.

When:

```systemverilog
rempty == 1'b1;
```

the read-side interface shall not accept another read request.

The empty comparison uses `rgraynext` instead of the current `rptr`. This ensures that `rempty` asserts immediately after the final valid FIFO entry is consumed.

---

### 11.6 Almost-Empty Flag Behavior

The almost-empty flag is calculated by evaluating the read pointer one additional increment beyond the next read pointer.

```verilog
assign rgraynextm1 =
    ((rbinnext + 1'b1) >> 1) ^ (rbinnext + 1'b1);

assign arempty_val = (rgraynextm1 == rq2_wptr);
```

The almost-empty flag updates on the rising edge of `rclk`.

```verilog
always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
        arempty <= 1'b0;
    else
        arempty <= arempty_val;
end
```

For this RTL implementation:

```text
arempty = 1 indicates that one readable FIFO entry remains.
rempty  = 1 indicates that no readable FIFO entry remains.
```

For a FIFO depth of 16:

| Read-Domain Visible Occupancy | `arempty` | `rempty` |
|---:|---:|---:|
| 0 entries | `0` | `1` |
| 1 entry | `1` | `0` |
| 2 to 16 entries | `0` | `0` |

> `arempty` is an advisory status flag. `rempty` is the controlling flag that blocks reads.

---

### 11.7 Read Reset Behavior

When the read reset is asserted:

```verilog
rrst_n == 1'b0;
```

the read-side state is reset asynchronously.

```verilog
{rbin, rptr} <= 0;
rempty       <= 1'b1;
arempty      <= 1'b0;
```

Expected read-side reset state:

| Signal | Reset Value |
|---|---:|
| `rbin` | `0` |
| `rptr` | `0` |
| `rempty` | `1` |
| `arempty` | `0` |

After read reset, the read side considers the FIFO empty because:

```text
rempty = 1
```

---

### 11.8 Read Data Validity

For the baseline first-word fall-through configuration:

```verilog
FALLTHROUGH = "TRUE"
```

`rdata` is valid only when:

```systemverilog
rempty == 1'b0;
```

When:

```systemverilog
rempty == 1'b1;
```

the read data value is unspecified and shall not be used for functional comparison.

A read data item is considered consumed only when:

```systemverilog
rinc && !rempty;
```

---

## 12. Clock-Domain Crossing Latency and Flag Ownership

The FIFO uses independent write and read clocks.

```text
Write clock domain: wclk
Read clock domain : rclk
```

Because the clocks are asynchronous, status information generated in one clock domain cannot be used directly in the other clock domain.

The FIFO transfers only Gray-coded pointer values across the clock boundary through two-flop synchronizers.

```text
Read pointer crossing into write domain:
    rptr -> wq1_rptr -> wq2_rptr

Write pointer crossing into read domain:
    wptr -> rq1_wptr -> rq2_wptr
```

---

### 12.1 Status Flag Ownership

Each status flag is valid only in the clock domain where it is generated.

| Signal | Owning Clock Domain | Generated By | Purpose |
|---|---|---|---|
| `wfull` | `wclk` | `wptr_full` | Blocks writes when no writable FIFO location remains. |
| `awfull` | `wclk` | `wptr_full` | Indicates that one writable FIFO location remains. |
| `rempty` | `rclk` | `rptr_empty` | Blocks reads when no readable FIFO entry remains. |
| `arempty` | `rclk` | `rptr_empty` | Indicates that one readable FIFO entry remains. |

The write-side interface must use:

```systemverilog
winc && !wfull;
```

The read-side interface must use:

```systemverilog
rinc && !rempty;
```

`wfull` and `awfull` shall not be used as synchronous control signals in the read clock domain.

`rempty` and `arempty` shall not be used as synchronous control signals in the write clock domain.

---

### 12.2 Write-to-Read Visibility Latency

When a write is accepted, data is written into FIFO memory immediately in the write clock domain. However, the read domain does not immediately know that the data is available.

The write pointer must be synchronized into the read clock domain.

```text
Accepted write on posedge wclk
    |
    v
wbin and wptr advance in write domain
    |
    v
wptr crosses asynchronously to read domain
    |
    v
rq1_wptr captures wptr on a posedge rclk
    |
    v
rq2_wptr captures rq1_wptr on a later posedge rclk
    |
    v
rptr_empty compares rq2_wptr with rgraynext
    |
    v
rempty may deassert
```

Therefore, after an accepted write into an empty FIFO:

```text
- `rempty` may remain asserted for multiple `rclk` cycles.
- The read side shall wait for `rempty=0` before accepting a read.
- The delay is expected behavior caused by CDC synchronization.
```

The exact number of read-clock cycles can vary depending on the relative timing of `wclk` and `rclk` edges.

---

### 12.3 Read-to-Write Visibility Latency

When a read is accepted, a FIFO location becomes free in the read clock domain. However, the write domain does not immediately know that space is available.

The read pointer must be synchronized into the write clock domain.

```text
Accepted read on posedge rclk
    |
    v
rbin and rptr advance in read domain
    |
    v
rptr crosses asynchronously to write domain
    |
    v
wq1_rptr captures rptr on a posedge wclk
    |
    v
wq2_rptr captures wq1_rptr on a later posedge wclk
    |
    v
wptr_full compares wq2_rptr with wgraynext
    |
    v
wfull may deassert
```

Therefore, after an accepted read from a full FIFO:

```text
- `wfull` may remain asserted for multiple `wclk` cycles.
- The write side shall wait for `wfull=0` before accepting another write.
- The delay is expected behavior caused by CDC synchronization.
```

The exact number of write-clock cycles can vary depending on the relative timing of `wclk` and `rclk` edges.

---

### 12.4 Conservative Local-Domain View

The synchronized remote pointer can be delayed relative to the actual remote pointer.

As a result:

```text
The write domain can temporarily believe that the FIFO is fuller
than the physical memory occupancy.

The read domain can temporarily believe that the FIFO is emptier
than the physical memory occupancy.
```

This conservative behavior is intentional.

It ensures that:

```text
- The write side does not overwrite unread data.
- The read side does not read data that has not been safely observed.
```

---

### 12.5 Verification Requirements for CDC Latency

Verification shall not require immediate cross-domain flag updates.

Incorrect expectation:

```text
A write occurs on wclk.
rempty must deassert immediately.
```

Correct expectation:

```text
A write occurs on wclk.
rempty eventually deasserts after synchronization into rclk domain.
```

Incorrect expectation:

```text
A read occurs on rclk while FIFO is full.
wfull must deassert immediately.
```

Correct expectation:

```text
A read occurs on rclk while FIFO is full.
wfull eventually deasserts after synchronization into wclk domain.
```

Tests should use timeout-based waiting for remote-domain flag transitions.

Recommended baseline timeout:

```text
Wait for remote flag transition:
    Up to 5 destination-clock cycles.
```

The timeout may be adjusted based on the selected clock frequencies and simulation scheduling.

---

## 13. Concurrent Read and Write Operations

The FIFO supports independent write and read activity because the write and read interfaces use separate clock domains.

```text
Write interface clock: wclk
Read interface clock : rclk
```

A write operation and a read operation may occur independently, including at closely spaced simulation times or at the same simulation timestamp.

---

### 13.1 Independent Interface Operation

Write-side activity is controlled by:

```systemverilog
write_accepted = winc && !wfull;
```

Read-side activity is controlled by:

```systemverilog
read_accepted = rinc && !rempty;
```

The two acceptance conditions are evaluated independently in their local clock domains.

| Write-Side Condition | Read-Side Condition | Expected Behavior |
|---|---|---|
| No accepted write | No accepted read | FIFO contents remain unchanged. |
| Accepted write | No accepted read | A new item is added to the FIFO tail. |
| No accepted write | Accepted read | The oldest FIFO item is removed from the FIFO front. |
| Accepted write | Accepted read | One item is added to the FIFO tail and one item is removed from the FIFO front. |

---

### 13.2 Concurrent Write and Read Timing

Write operations occur on the rising edge of `wclk`.

```verilog
always @(posedge wclk) begin
    if (winc && !wfull)
        mem[waddr] <= wdata;
end
```

Read pointer operations occur on the rising edge of `rclk`.

```verilog
assign rbinnext = rbin + (rinc & ~rempty);
```

Because `wclk` and `rclk` are asynchronous, there is no fixed ordering between a write edge and a read edge.

Example timing:

```text
wclk:      ^---------^---------^---------^
rclk:   ^------^---------^---------^------

Write:      W1                  W2
Read:    R1             R2
```

The FIFO must operate correctly regardless of the relative clock-edge positions.

---

### 13.3 FIFO Ordering Requirement

The FIFO shall preserve first-in first-out ordering for all accepted transactions.

```text
The first accepted write must be the first accepted read.
```

Example:

```text
Accepted writes:
    W1 = 8'h11
    W2 = 8'h22
    W3 = 8'h33

Accepted reads:
    R1 must return 8'h11
    R2 must return 8'h22
    R3 must return 8'h33
```

This requirement applies regardless of:

```text
- Write clock frequency
- Read clock frequency
- Clock phase relationship
- Number of concurrent operations
- Pointer wraparound
- Full and empty transitions
```

---

### 13.4 Full and Empty Behavior During Concurrent Traffic

During concurrent read and write activity, `wfull` and `rempty` may not reflect the same instantaneous FIFO occupancy because each domain receives remote pointer information after synchronization delay.

Examples:

```text
- The write domain may continue to see wfull=1 after a read has occurred.
- The read domain may continue to see rempty=1 after a write has occurred.
```

This is expected behavior.

The source-side protocol remains:

```text
Write only when wfull == 0.
Read only when rempty == 0.
```

The FIFO shall not:

```text
- Accept a write when wfull=1.
- Accept a read when rempty=1.
- Lose accepted data.
- Duplicate accepted data.
- Reorder accepted data.
```

---

### 13.5 Simultaneous Activity at Boundary Conditions

#### Write Attempt While Full and Read Occurs

A write-side request can be blocked while the FIFO is full, even if a read occurs near the same time in the read domain.

```text
Reason:
    The read pointer must synchronize into the write domain before
    wfull can deassert.
```

Expected behavior:

```text
- Write remains blocked while wfull=1.
- A later write may be accepted after wfull deasserts.
- No unread data is overwritten.
```

---

#### Read Attempt While Empty and Write Occurs

A read-side request can be blocked while the FIFO is empty, even if a write occurs near the same time in the write domain.

```text
Reason:
    The write pointer must synchronize into the read domain before
    rempty can deassert.
```

Expected behavior:

```text
- Read remains blocked while rempty=1.
- A later read may be accepted after rempty deasserts.
- No unwritten data is consumed.
```

---

### 13.6 Verification Requirement

The verification environment shall generate independent write and read traffic.

At minimum, verification shall include:

```text
- Write-only periods
- Read-only periods
- Simultaneous write/read periods
- Bursty write traffic with intermittent reads
- Bursty read traffic with intermittent writes
- Full-to-read recovery
- Empty-to-write recovery
- Different write/read clock frequencies
```

For all tests, the primary data-integrity requirement is:

```text
Every accepted read must match the oldest accepted write
that has not already been read.
```

---

## 14. Design Assumptions and Known Limitations

This section documents assumptions and RTL characteristics that affect system integration and verification.

---

### 14.1 Baseline Configuration

The baseline verification configuration is:

```verilog
DSIZE       = 8
ASIZE       = 4
FALLTHROUGH = "TRUE"
```

Derived values:

```text
Data width = 8 bits
FIFO depth = 2^ASIZE = 16 entries
Read mode  = First-word fall-through
```

Other supported parameter values may be verified in separate parameterized regressions.

---

### 14.2 Memory Is Not Reset

The `fifomem` module does not include a reset input.

```verilog
reg [DATASIZE-1:0] mem [0:DEPTH-1];
```

As a result:

```text
- FIFO memory contents are not cleared by `wrst_n`.
- FIFO memory contents are not cleared by `rrst_n`.
- Memory values can be unknown after simulation startup.
- Memory values can retain previous values after a reset event.
```

FIFO correctness after reset is achieved by resetting pointers and status flags, not memory entries.

Verification requirement:

```text
`rdata` shall not be checked when `rempty=1`.
```

---

### 14.3 Read Data Validity

For the baseline configuration:

```verilog
FALLTHROUGH = "TRUE"
```

the read data path is combinational:

```verilog
assign rdata = mem[raddr];
```

Therefore:

```text
- `rdata` may change when `raddr` changes.
- `rdata` may change when the write port updates `mem[raddr]`.
- `rdata` is considered valid only when `rempty=0`.
- `rdata` is consumed only on an accepted read: `rinc && !rempty`.
```

When the FIFO is empty:

```systemverilog
rempty == 1'b1;
```

the value of `rdata` is unspecified and shall not be used for functional checking.

---

### 14.4 Local-Domain Status Flags

The FIFO status flags are local-domain signals.

| Signal | Valid Domain | Usage |
|---|---|---|
| `wfull` | Write domain (`wclk`) | Controls whether a write request may be accepted. |
| `awfull` | Write domain (`wclk`) | Indicates one writable FIFO location remains. |
| `rempty` | Read domain (`rclk`) | Controls whether a read request may be accepted. |
| `arempty` | Read domain (`rclk`) | Indicates one readable FIFO entry remains. |

The following usage is required:

```systemverilog
write_accepted = winc && !wfull;
read_accepted  = rinc && !rempty;
```

Flags must not be assumed to update immediately after an operation in the opposite clock domain.

---

### 14.5 CDC Synchronization Latency

The read and write pointers cross clock domains through two-flop synchronizers.

```text
rptr -> wq1_rptr -> wq2_rptr
wptr -> rq1_wptr -> rq2_wptr
```

Consequently:

```text
- A newly written entry can take multiple `rclk` cycles to become visible.
- A newly freed entry can take multiple `wclk` cycles to become visible.
- `rempty` can remain asserted temporarily after a write.
- `wfull` can remain asserted temporarily after a read.
```

This conservative behavior is intentional and prevents unsafe read/write operations.

---

### 14.6 Independent Reset Behavior

The FIFO provides separate asynchronous resets:

```text
Write-domain reset: wrst_n
Read-domain reset : rrst_n
```

The provided RTL defines local reset behavior:

```text
When wrst_n=0:
    wbin   = 0
    wptr   = 0
    wfull  = 0
    awfull = 0

When rrst_n=0:
    rbin     = 0
    rptr     = 0
    rempty   = 1
    arempty  = 0
```

The RTL does not explicitly define system-level data-preservation semantics when only one reset is asserted while the FIFO contains valid data.

Baseline verification assumption:

```text
Both `wrst_n` and `rrst_n` are asserted together during initial reset.
```

Independent reset assertion and release tests may be executed as robustness tests. Their expected behavior must be defined by the system-level specification before strict data-integrity checking is applied.

---

### 14.7 Dual-Clock Memory Access Assumption

The FIFO uses a memory that is written in the write clock domain and read in the read clock domain.

```text
Write port:
    wclk, waddr, wdata

Read port:
    rclk, raddr, rdata
```

The FIFO pointer logic is intended to prevent legal reads from accessing unwritten entries and legal writes from overwriting unread entries.

This specification defines expected behavior only for legal FIFO protocol operations:

```systemverilog
write_accepted = winc && !wfull;
read_accepted  = rinc && !rempty;
```

Direct same-address read/write collision behavior is not separately specified outside the FIFO protocol.

---

### 14.8 Almost-Flag Thresholds

Based on the provided RTL:

```text
awfull:
    Asserted when one writable location remains.

arempty:
    Asserted when one readable entry remains.
```

For default depth `DEPTH=16`:

| Visible Occupancy | `awfull` | `wfull` |
|---:|---:|---:|
| 0 to 14 entries | `0` | `0` |
| 15 entries | `1` | `0` |
| 16 entries | Advisory value not used for flow control | `1` |

| Visible Occupancy | `arempty` | `rempty` |
|---:|---:|---:|
| 0 entries | `0` | `1` |
| 1 entry | `1` | `0` |
| 2 to 16 entries | `0` | `0` |

> Visible occupancy is local-domain occupancy inferred from synchronized remote pointer information. It may lag physical memory occupancy because of CDC synchronization latency.

---

## 15. References

This design specification is based on the following RTL source modules:

```text
async_fifo.v
fifomem.v
sync_r2w.v
sync_w2r.v
wptr_full.v
rptr_empty.v
```

---




