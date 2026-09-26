# Test List
#
# Comment out tests that are not implemented or not compiling yet.
# Add future tests here when ready.
#------------------------------------------------------------------------------

TESTS=(
  fifo_reset_test
  fifo_single_write_read_test
  fifo_multiple_write_read_test
  fifo_write_only_test
  fifo_read_only_test
  fifo_almost_full_test
  fifo_almost_empty_test
  fifo_fwft_test
  fifo_concrnt_rw_test
)

#------------------------------------------------------------------------------
# Regression Counters and Result Arrays
#------------------------------------------------------------------------------

PASS_COUNT=0
FAIL_COUNT=0

PASS_TESTS=()
FAIL_TESTS=()

#------------------------------------------------------------------------------
# Compile Testbench
#
# Compilation occurs once before all simulations.
#------------------------------------------------------------------------------

echo "================================================================"
echo "COMPILING ASYNC FIFO UVM TESTBENCH"
echo "================================================================"

rm -rf simv simv.daidir csrc
rm -f ucli.key vc_hdrs.h compile.log cov coverage_report

vcs -full64 -sverilog \
    -ntb_opts uvm-1.2 \
    -debug_all \
    -lca \
    -file sim.f \
    -l compile.log \
    -cm line+cond+branch+tgl+fsm \
    -cm_dir cov/async_fifo.vdb \
    -timescale=1ns/10ps \
    -o simv

COMPILE_STATUS=$?

if [[ "${COMPILE_STATUS}" -ne 0 ]]; then
  echo ""
  echo "ERROR: VCS compilation failed."
  echo "Check compile.log for details:"
  echo "  less compile.log"
  exit 1
fi

if [[ ! -x "${SIM}" ]]; then
  echo ""
  echo "ERROR: Compilation completed but '${SIM}' was not generated."
  exit 1
fi

echo "Compilation completed successfully."

#------------------------------------------------------------------------------
# Initial Checks
#------------------------------------------------------------------------------

if [[ ! -x "${SIM}" ]]; then
  echo "ERROR: Simulation executable '${SIM}' was not found or is not executable."
  echo "Compile the testbench first, for example:"
  echo ""
  echo "  vcs -full64 -sverilog -ntb_opts uvm-1.2 \\"
  echo "      -f sim.f \\"
  echo "      -cm fcover \\"
  echo "      -o simv"
  echo ""
  exit 1
fi

# Create output directories if they do not already exist.
mkdir -p "${LOG_DIR}"
mkdir -p "${COV_DIR}"

#------------------------------------------------------------------------------
# Helper Function: Check Test Result
#
# A test fails if:
#
#   1. VCS simulation returns a non-zero exit code.
#   2. UVM prints an actual UVM_ERROR/UVM_FATAL message.
#   3. UVM report summary shows non-zero errors/fatals.
#------------------------------------------------------------------------------
check_result() {
  local RUN_NAME="$1"
  local LOG_FILE="$2"
  local SIM_STATUS="$3"

  # Simulation itself failed.
  if [[ "${SIM_STATUS}" -ne 0 ]]; then
    echo "RESULT: FAIL -> ${RUN_NAME}"
    echo "Reason: Simulation returned exit code ${SIM_STATUS}"

    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_TESTS+=("${RUN_NAME}")
    return
  fi

  # Check UVM final summary for non-zero error/fatal counts.
  #
  # Matches:
  #   UVM_ERROR : 1
  #   UVM_ERROR :    12
  #   UVM_FATAL : 1
  #
  # Does NOT match:
  #   UVM_ERROR : 0
  #   UVM_FATAL : 0
  #
  if grep -qE "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*" "${LOG_FILE}"; then
    echo "RESULT: FAIL -> ${RUN_NAME}"
    echo "Reason: Non-zero UVM_ERROR or UVM_FATAL count found in summary."

    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_TESTS+=("${RUN_NAME}")
    return
  fi

  # Check actual runtime UVM error/fatal messages.
  #
  # Typical UVM runtime messages look like:
  #
  #   UVM_ERROR file.sv(123) @ 100: ...
  #   UVM_FATAL file.sv(123) @ 100: ...
  #
  # The [^:] prevents matching UVM summary lines:
  #
  #   UVM_ERROR : 0
  #
  if grep -qE "^UVM_(ERROR|FATAL)[[:space:]]+[^:]" "${LOG_FILE}"; then
    echo "RESULT: FAIL -> ${RUN_NAME}"
    echo "Reason: Runtime UVM_ERROR or UVM_FATAL message found."

    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_TESTS+=("${RUN_NAME}")
    return
  fi

  # No failures found.
  echo "RESULT: PASS -> ${RUN_NAME}"

  PASS_COUNT=$((PASS_COUNT + 1))
  PASS_TESTS+=("${RUN_NAME}")
}

#------------------------------------------------------------------------------
# Helper Function: Run One Standard UVM Test
#
# Arguments:
#   $1 : Unique run name
#   $2 : UVM test class name
#
# Example:
#   run_test "fifo_reset_test" "fifo_reset_test"
#------------------------------------------------------------------------------

run_test() {
  local RUN_NAME="$1"
  local TEST_NAME="$2"

  local LOG_FILE="${LOG_DIR}/${RUN_NAME}.log"
  local COV_DB="${COV_DIR}/${RUN_NAME}.vdb"

  echo ""
  echo "================================================================"
  echo "RUN NAME : ${RUN_NAME}"
  echo "UVM TEST : ${TEST_NAME}"
  echo "LOG FILE : ${LOG_FILE}"
  echo "COVERAGE : ${COV_DB}"
  echo "================================================================"

  # Remove previous coverage database and log for this exact run name.
  rm -rf "${COV_DB}"
  rm -f "${LOG_FILE}"

  # Run simulation.
  #
  # tee writes output to terminal and log file simultaneously.
  #
  # PIPESTATUS[0] captures the actual exit code of simv, not tee.
  "${SIM}" \
  +UVM_TESTNAME="${TEST_NAME}" \
  -cm line+cond+branch+tgl+fcover \
  -cm_dir "${COV_DIR}/async_fifo.vdb" \
  -cm_name "${RUN_NAME}" \
  | tee "${LOG_FILE}"

  local SIM_STATUS=${PIPESTATUS[0]}

  check_result "${RUN_NAME}" "${LOG_FILE}" "${SIM_STATUS}"
}

#------------------------------------------------------------------------------
# Helper Function: Run Clock-Ratio Test
#
# Arguments:
#   $1 : Unique run name
#   $2 : Write clock half-period in ns
#   $3 : Read clock half-period in ns
#
# Example:
#   run_clock_ratio_test "clock_write_fast" 2 10
#
# This expects tb_top to read:
#
#   +WCLK_HALF_NS=<value>
#   +RCLK_HALF_NS=<value>
#------------------------------------------------------------------------------

run_clock_ratio_test() {
  local RUN_NAME="$1"
  local WCLK_HALF_NS="$2"
  local RCLK_HALF_NS="$3"

  local LOG_FILE="${LOG_DIR}/${RUN_NAME}.log"
  local COV_DB="${COV_DIR}/${RUN_NAME}.vdb"

  echo ""
  echo "================================================================"
  echo "RUN NAME        : ${RUN_NAME}"
  echo "UVM TEST        : fifo_clock_ratio_test"
  echo "WCLK HALF PERIOD: ${WCLK_HALF_NS} ns"
  echo "RCLK HALF PERIOD: ${RCLK_HALF_NS} ns"
  echo "WCLK PERIOD     : $((2 * WCLK_HALF_NS)) ns"
  echo "RCLK PERIOD     : $((2 * RCLK_HALF_NS)) ns"
  echo "LOG FILE        : ${LOG_FILE}"
  echo "COVERAGE        : ${COV_DB}"
  echo "================================================================"

  rm -rf "${COV_DB}"
  rm -f "${LOG_FILE}"

  "${SIM}" \
    +UVM_TESTNAME=fifo_clock_ratio_test \
    +WCLK_HALF_NS="${WCLK_HALF_NS}" \
    +RCLK_HALF_NS="${RCLK_HALF_NS}" \
    -cm line+cond+branch+tgl+fcover \
    -cm_dir "${COV_DIR}/async_fifo.vdb" \
    -cm_name "${RUN_NAME}" \
    | tee "${LOG_FILE}"

  local SIM_STATUS=${PIPESTATUS[0]}

  check_result "${RUN_NAME}" "${LOG_FILE}" "${SIM_STATUS}"
}

#------------------------------------------------------------------------------
# Run Baseline Directed Tests
#------------------------------------------------------------------------------

echo ""
echo "################################################################"
echo "# ASYNCHRONOUS FIFO UVM REGRESSION START"
echo "################################################################"

for TEST in "${TESTS[@]}"; do
  run_test "${TEST}" "${TEST}"
done

#------------------------------------------------------------------------------
# Run Clock-Ratio Configurations
#
# Comment these out until fifo_clock_ratio_test is implemented and compiled.
#------------------------------------------------------------------------------

run_clock_ratio_test "fifo_clock_ratio_write_fast" 2 10
run_clock_ratio_test "fifo_clock_ratio_read_fast" 10 2
run_clock_ratio_test "fifo_clock_ratio_async" 5 8

#------------------------------------------------------------------------------
# Print Regression Summary
#------------------------------------------------------------------------------

echo ""
echo "################################################################"
echo "# ASYNCHRONOUS FIFO UVM REGRESSION SUMMARY"
echo "################################################################"
echo "PASS COUNT : ${PASS_COUNT}"
echo "FAIL COUNT : ${FAIL_COUNT}"
echo "################################################################"

echo ""
echo "PASSED TESTS:"
if [[ "${#PASS_TESTS[@]}" -eq 0 ]]; then
  echo "  None"
else
  for TEST in "${PASS_TESTS[@]}"; do
    echo "  PASS : ${TEST}"
  done
fi

echo ""
echo "FAILED TESTS:"
if [[ "${#FAIL_TESTS[@]}" -eq 0 ]]; then
  echo "  None"
else
  for TEST in "${FAIL_TESTS[@]}"; do
    echo "  FAIL : ${TEST}"
  done
fi

#------------------------------------------------------------------------------
# Merge Coverage
#
# Merge only if one or more .vdb coverage databases exist.
#------------------------------------------------------------------------------

VDB_LIST=( "${COV_DIR}"/*.vdb )

if [[ -e "${VDB_LIST[0]}" ]]; then
  echo ""
  echo "################################################################"
  echo "# MERGING COVERAGE DATABASES"
  echo "################################################################"

  rm -rf "${REPORT_DIR}"

  urg -dir cov/async_fifo.vdb -report coverage_report

  URG_STATUS=${PIPESTATUS[0]}

  if [[ "${URG_STATUS}" -eq 0 ]]; then
    echo ""
    echo "Coverage report generated successfully."

    if [[ -f "${REPORT_DIR}/dashboard.html" ]]; then
      echo "Open this report in a browser:"
      echo "  ${REPORT_DIR}/dashboard.html"
    elif [[ -f "${REPORT_DIR}/index.html" ]]; then
      echo "Open this report in a browser:"
      echo "  ${REPORT_DIR}/index.html"
    else
      echo "Check coverage report directory:"
      echo "  ${REPORT_DIR}/"
    fi
  else
    echo ""
    echo "WARNING: URG coverage merge failed."
    echo "Check this log:"
    echo "  ${LOG_DIR}/coverage_merge.log"
  fi
else
  echo ""
  echo "WARNING: No .vdb coverage databases found in '${COV_DIR}'."
  echo "Make sure VCS was compiled with coverage enabled, for example:"
  echo "  -cm fcover"
fi

#------------------------------------------------------------------------------
# Final Exit Status
#------------------------------------------------------------------------------

echo ""
echo "################################################################"
echo "# REGRESSION COMPLETE"
echo "################################################################"

if [[ "${FAIL_COUNT}" -ne 0 ]]; then
  echo "Regression finished with failures."
  echo "Check individual logs in: ${LOG_DIR}/"
  exit 1
else
  echo "Regression passed."
  echo "Check individual logs in: ${LOG_DIR}/"
  exit 0
fi
