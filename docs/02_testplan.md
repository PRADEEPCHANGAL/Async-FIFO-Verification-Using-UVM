# Asynchronous FIFO Detailed Test Specifications

## Document Revision History

| Version | Date | Author | Description |
|---|---|---|---|
| 0.1 | TBD | TBD | Initial detailed test specifications. |

---

## 1. Common Test Configuration

Unless otherwise stated, all tests use the following DUT configuration:

```verilog
DSIZE       = 8
ASIZE       = 4
FALLTHROUGH = "TRUE"
```

Derived values:

```text
DATA_WIDTH = 8 bits
DEPTH      = 2^ASIZE = 16 entries
READ_MODE  = First-word fall-through
```

Default clock configuration:

```text
wclk period = 10 ns
rclk period = 14 ns
```

The different clock periods ensure that write and read clock edges are asynchronous.

---

## 2. Common Definitions

### 2.1 Accepted Write

```systemverilog
write_accepted = winc && !wfull;
```

An accepted write occurs on a rising edge of `wclk`.

Expected result:

```text
- wdata is stored in FIFO memory.
- Write pointer advances.
- Data is added to the scoreboard reference queue.
```

---

### 2.2 Accepted Read

```systemverilog
read_accepted = rinc && !rempty;
```

An accepted read occurs on a rising edge of `rclk`.

Expected result:

```text
- The oldest FIFO item is consumed.
- Read pointer advances.
- The read monitor captures the consumed FWFT data.
- Scoreboard compares DUT rdata against the oldest reference-queue item.
```

---

### 2.3 Synchronization Latency

The FIFO uses two-flop pointer synchronizers.

Therefore:

```text
- A write is not immediately visible in the read domain.
- A read is not immediately visible in the write domain.
- rempty and wfull can change after synchronization delay.
```

Tests must wait for status changes using a timeout rather than assuming an exact number of clock cycles.

Recommended timeout examples:

```text
Wait for rempty deassertion:
    Maximum 5 rclk cycles

Wait for wfull deassertion after a read:
    Maximum 5 wclk cycles
```

---

## 3. Test Specifications

---

## FIFO_TC_001: reset_test

### Objective

Verify that the FIFO initializes correctly when both resets are asserted and released.

### Preconditions

```text
- No read or write request is active.
- winc = 0
- rinc = 0
```

### Stimulus Sequence

1. Start `wclk` and `rclk`.
2. Drive both resets low:

   ```systemverilog
   wrst_n = 0;
   rrst_n = 0;
   ```

3. Hold reset active for at least:

   ```text
   2 wclk cycles
   2 rclk cycles
   ```

4. Verify reset values while resets are asserted.
5. Release both resets:

   ```systemverilog
   wrst_n = 1;
   rrst_n = 1;
   ```

6. Wait for at least:

   ```text
   2 wclk cycles
   2 rclk cycles
   ```

7. Keep `winc=0` and `rinc=0`.

### Expected Checks

| Signal | Expected Value |
|---|---:|
| `wfull` | `0` |
| `awfull` | `0` |
| `rempty` | `1` |
| `arempty` | `0` |

Additional checks:

```text
- No accepted write occurs during reset.
- No accepted read occurs during reset.
- Scoreboard reference queue remains empty.
- rdata is not checked because rempty=1.
```

### Pass Criteria

```text
- All reset flag values match expected values.
- No scoreboard mismatch occurs.
- No UVM error or fatal message occurs.
```

---

## FIFO_TC_002: single_write_read_test

### Objective

Verify that one accepted write is transferred correctly to the read domain and read back correctly.

### Preconditions

```text
- FIFO has completed initial reset.
- rempty = 1
- wfull = 0
- Scoreboard queue is empty.
```

### Test Data

```systemverilog
wdata = 8'hA5;
```

### Stimulus Sequence

1. Apply one write request:

   ```systemverilog
   winc  = 1;
   wdata = 8'hA5;
   ```

2. Hold the request stable until the next `posedge wclk`.
3. After the write edge, deassert `winc`.

   ```systemverilog
   winc = 0;
   ```

4. Confirm that the write was accepted:

   ```systemverilog
   winc && !wfull
   ```

   The write monitor sends `8'hA5` to the scoreboard.

5. Wait until the read-domain empty flag deasserts:

   ```text
   Wait until rempty == 0.
   Timeout after 5 rclk cycles.
   ```

6. Before asserting `rinc`, verify FWFT behavior:

   ```text
   rdata should show 8'hA5 while rempty=0.
   ```

7. Apply one read request:

   ```systemverilog
   rinc = 1;
   ```

8. Hold `rinc` until the next `posedge rclk`.
9. The read monitor captures `rdata` for the accepted read.
10. Deassert `rinc`.

    ```systemverilog
    rinc = 0;
    ```

11. Wait until:

    ```text
    rempty == 1
    ```

### Expected Checks

```text
- Exactly one accepted write occurs.
- Exactly one accepted read occurs.
- rdata at the accepted read equals 8'hA5.
- Scoreboard queue becomes empty after the read.
- rempty eventually asserts after the read.
```

### Pass Criteria

```text
- Scoreboard reports expected data = actual data = 8'hA5.
- FIFO returns to empty state.
- No error or fatal message occurs.
```

---

## FIFO_TC_003: multiple_write_read_test

### Objective

Verify FIFO ordering for a burst of writes followed by a burst of reads.

### Preconditions

```text
- FIFO is reset.
- FIFO is empty.
```

### Test Data

Use unique values to detect reordering:

```systemverilog
8'h11, 8'h22, 8'h33, 8'h44
```

### Stimulus Sequence

1. Perform four accepted writes on successive or spaced `wclk` cycles:

   ```text
   Write 1: 8'h11
   Write 2: 8'h22
   Write 3: 8'h33
   Write 4: 8'h44
   ```

2. After each write:
   - Deassert `winc`.
   - Allow the write monitor to publish the accepted write.
   - Confirm that `wfull` remains low.

3. Wait until the read domain sees available data:

   ```text
   Wait until rempty == 0.
   ```

4. Perform four accepted reads on `rclk` edges.

5. For each accepted read:
   - Capture read data.
   - Compare against the scoreboard queue front item.
   - Deassert `rinc` after the active read edge.

6. Wait until:

   ```text
   rempty == 1
   ```

### Expected Checks

| Read Number | Expected `rdata` |
|---:|---|
| 1 | `8'h11` |
| 2 | `8'h22` |
| 3 | `8'h33` |
| 4 | `8'h44` |

Additional checks:

```text
- No data is lost.
- No data is duplicated.
- No data is reordered.
- Scoreboard queue is empty after fourth read.
```

### Pass Criteria

```text
All four read values match the write order exactly.
```

---

## FIFO_TC_004: write_only_test

### Objective

Verify write-side operation when multiple writes occur before any read request.

### Preconditions

```text
- FIFO is reset and empty.
- wfull = 0.
```

### Stimulus Sequence

1. Generate a burst of writes smaller than FIFO depth.

   Example burst length:

   ```text
   8 writes for a FIFO depth of 16.
   ```

2. Use unique data values:

   ```text
   8'h00 through 8'h07
   ```

3. For each write:
   - Assert `winc=1`.
   - Drive a unique `wdata`.
   - Wait for `posedge wclk`.
   - Deassert `winc`.

4. Do not assert `rinc` during the write burst.

5. Wait for write-pointer synchronization into the read domain.

6. Confirm:

   ```text
   rempty eventually becomes 0.
   ```

7. Read all written entries and verify them through the scoreboard.

### Expected Checks

```text
- Every write is accepted.
- wfull remains low.
- Scoreboard queue contains all written items.
- Read domain eventually observes non-empty state.
- Subsequent reads return all values in original write order.
```

### Pass Criteria

```text
All burst data is preserved and read back in FIFO order.
```

---

## FIFO_TC_005: read_only_empty_test

### Objective

Verify that read requests are blocked while the FIFO is empty.

### Preconditions

```text
- FIFO is reset.
- rempty = 1.
- Scoreboard queue is empty.
```

### Stimulus Sequence

1. Keep write interface idle:

   ```systemverilog
   winc = 0;
   ```

2. Assert read requests for multiple read-clock cycles:

   ```text
   Assert rinc for 5 consecutive rclk cycles.
   ```

3. No writes are performed during the test.

### Expected Checks

```text
- rempty remains asserted.
- No accepted read occurs.
- Read monitor does not send a valid read transaction to scoreboard.
- Scoreboard queue remains empty.
- No reference-model underflow occurs.
- rdata is not compared because FIFO remains empty.
```

### Pass Criteria

```text
No data compare is attempted and no read is accepted.
```

---

## FIFO_TC_006: fill_fifo_test

### Objective

Verify FIFO full assertion after exactly `DEPTH` accepted writes.

### Preconditions

```text
- FIFO is reset and empty.
- No reads are issued.
- DEPTH = 16.
```

### Stimulus Sequence

1. Perform exactly `DEPTH` writes:

   ```text
   Number of writes = 16
   ```

2. Use unique data values:

   ```text
   8'h00 through 8'h0F
   ```

3. For each write:
   - Assert `winc`.
   - Drive unique data.
   - Wait for `posedge wclk`.
   - Deassert `winc`.

4. After the 16th accepted write, sample write-side flags on `wclk`.

5. Do not perform reads until full state has been checked.

6. Then read all stored entries to verify that full state did not corrupt data.

### Expected Checks

```text
- First 16 writes are accepted.
- wfull is low before the final accepted write.
- wfull asserts after the FIFO becomes full.
- No write data is lost.
- All 16 values can later be read in order.
```

### Pass Criteria

```text
- wfull asserts after 16 accepted writes.
- All 16 stored values are read back in order.
```

---

## FIFO_TC_007: write_when_full_test

### Objective

Verify that writes are blocked while `wfull=1`.

### Preconditions

```text
- FIFO is filled using FIFO_TC_006 sequence.
- wfull = 1.
- Scoreboard queue contains DEPTH items.
```

### Stimulus Sequence

1. After FIFO full assertion, attempt additional writes.

   Example:

   ```text
   Attempt 4 writes:
       8'hA0
       8'hA1
       8'hA2
       8'hA3
   ```

2. For each attempted write:
   - Assert `winc=1`.
   - Apply attempted write data.
   - Wait for `posedge wclk`.
   - Deassert `winc`.

3. Do not issue reads until all blocked-write attempts are complete.

4. Read all valid FIFO contents.

### Expected Checks

```text
- No blocked write is added to scoreboard queue.
- FIFO still contains only the original DEPTH items.
- Attempted data values 8'hA0 through 8'hA3 are never observed on rdata.
- Readback contains original DEPTH values in correct order.
```

### Pass Criteria

```text
No overflow data is observed at the read interface.
```

---

## FIFO_TC_008: drain_fifo_test

### Objective

Verify FIFO empty assertion after all stored data is consumed.

### Preconditions

```text
- FIFO contains DEPTH valid entries.
- rempty has deasserted.
```

### Stimulus Sequence

1. Wait until the read domain observes data:

   ```text
   rempty == 0
   ```

2. Perform exactly `DEPTH` accepted reads.

3. For each read:
   - Assert `rinc=1`.
   - Wait for `posedge rclk`.
   - Monitor captures FWFT data at accepted-read event.
   - Deassert `rinc`.

4. After final read, wait for read-side flag update.

### Expected Checks

```text
- All DEPTH entries are read in expected order.
- Scoreboard queue becomes empty.
- rempty asserts after the final accepted read.
- arempty is asserted when one item remains before final read.
```

### Pass Criteria

```text
FIFO becomes empty only after the final valid item is consumed.
```

---

## FIFO_TC_009: read_when_empty_test

### Objective

Verify that reads are blocked after the FIFO has been drained.

### Preconditions

```text
- FIFO has been drained.
- rempty = 1.
- Scoreboard queue is empty.
```

### Stimulus Sequence

1. Assert `rinc` for multiple read-clock cycles.

   ```text
   Assert rinc for 5 consecutive rclk cycles.
   ```

2. Keep write interface idle.

3. Observe read-side flags and scoreboard behavior.

### Expected Checks

```text
- rempty remains 1.
- No accepted read occurs.
- Scoreboard queue remains empty.
- No scoreboard underflow occurs.
- rdata is ignored while rempty=1.
```

### Pass Criteria

```text
No data is consumed during blocked read attempts.
```

---

## FIFO_TC_010: almost_full_test

### Objective

Verify `awfull` assertion when one writable location remains.

### Preconditions

```text
- FIFO is reset and empty.
- No reads are performed.
- DEPTH = 16.
```

### Stimulus Sequence

1. Perform `DEPTH-1` accepted writes.

   ```text
   Number of writes = 15
   ```

2. After the 15th accepted write, sample flags in the write domain.

3. Perform one additional write.

4. Sample flags again.

### Expected Checks

After 15 accepted writes:

| Signal | Expected Value |
|---|---:|
| `awfull` | `1` |
| `wfull` | `0` |

After 16th accepted write:

| Signal | Expected Value |
|---|---:|
| `wfull` | `1` |

Additional checks:

```text
- All 16 items remain readable.
- Data ordering remains correct.
```

### Pass Criteria

```text
awfull asserts with one remaining writable location and wfull asserts after final location is written.
```

---

## FIFO_TC_011: almost_empty_test

### Objective

Verify `arempty` assertion when one readable item remains.

### Preconditions

```text
- FIFO is reset.
- FIFO is loaded with at least 2 entries.
```

### Stimulus Sequence

1. Write two unique data items.

   Example:

   ```text
   8'h55
   8'hAA
   ```

2. Wait until:

   ```text
   rempty == 0
   ```

3. Perform one accepted read.

4. Wait for read-side flag update.

5. Sample `arempty` and `rempty`.

6. Perform one additional accepted read.

7. Sample `rempty`.

### Expected Checks

After first read, one item remains:

| Signal | Expected Value |
|---|---:|
| `arempty` | `1` |
| `rempty` | `0` |

After second read, zero items remain:

| Signal | Expected Value |
|---|---:|
| `rempty` | `1` |

### Pass Criteria

```text
arempty asserts only when one readable entry remains, and rempty asserts after the final read.
```

---

## FIFO_TC_012: fwft_test

### Objective

Verify first-word fall-through behavior when `FALLTHROUGH="TRUE"`.

### Preconditions

```text
- FIFO is reset and empty.
- rinc = 0.
```

### Test Data

```systemverilog
wdata = 8'hC3;
```

### Stimulus Sequence

1. Perform one accepted write with `wdata=8'hC3`.
2. Keep `rinc=0`.
3. Wait for the write pointer to synchronize into the read domain.
4. Wait until:

   ```text
   rempty == 0
   ```

5. Before asserting `rinc`, sample `rdata`.
6. Assert one read request and consume the item.

### Expected Checks

Before any read request:

| Signal | Expected Value |
|---|---|
| `rempty` | `0` |
| `rdata` | `8'hC3` |
| `rinc` | `0` |

After accepted read:

```text
- Scoreboard confirms read data equals 8'hC3.
- rempty eventually returns to 1.
```

### Pass Criteria

```text
The first written word becomes visible on rdata before rinc is asserted.
```

---

## FIFO_TC_013: concurrent_rw_test

### Objective

Verify correct FIFO behavior during concurrent independent write and read activity.

### Preconditions

```text
- FIFO is reset.
- wclk and rclk are asynchronous.
```

### Stimulus Sequence

1. Start a write sequence that generates bursts of writes.

   Example behavior:

   ```text
   - Random burst length: 1 to 4 writes
   - Random idle gap: 0 to 3 wclk cycles
   - Unique or randomized data
   ```

2. Start a read sequence independently.

   Example behavior:

   ```text
   - Random burst length: 1 to 4 reads
   - Random idle gap: 0 to 3 rclk cycles
   ```

3. Run both sequences concurrently for a fixed duration.

   Example:

   ```text
   500 write-clock cycles
   ```

4. Stop write generation.
5. Continue reading until FIFO becomes empty.
6. Check that scoreboard queue is empty.

### Expected Checks

```text
- Every accepted write is stored in the reference queue.
- Every accepted read matches the oldest queue item.
- No data is lost.
- No data is duplicated.
- No data is corrupted.
- No data is reordered.
- Blocked writes and blocked reads do not modify the reference model.
```

### Pass Criteria

```text
- Scoreboard reports zero mismatches.
- Reference queue is empty at end of test.
- No UVM error or fatal message occurs.
```

---
