class fifo_base_test extends uvm_test;
`uvm_component_utils(fifo_base_test)

fifo_env env;

virtual async_fifo_if vif;

//--------------------------------------------------------------------------
  // Constructor
//--------------------------------------------------------------------------
function new(string name, uvm_component parent);
super.new(name,parent);
endfunction

//--------------------------------------------------------------------------
  // build_phase
//--------------------------------------------------------------------------
function void build_phase(uvm_phase phase);
env=fifo_env::type_id::create("env",this);
if(!uvm_config_db #(virtual async_fifo_if)::get(this,"","vif",vif))
 `uvm_error("NOVIF","No virtual interface set");
endfunction

//--------------------------------------------------------------------------
  // end_of_elaboration_phase
  //
  // Print the UVM hierarchy before simulation starts.
//--------------------------------------------------------------------------
function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);

    uvm_top.print_topology();
  endfunction

//--------------------------------------------------------------------------
  // wait_for_initial_reset_release
  //
  // Common helper task for derived tests.
//--------------------------------------------------------------------------
task wait_for_initial_reset_release(input time reset_timeout = 1_000ns);

    bit reset_released;

    reset_released = 1'b0;

     fork

    // Thread 1:
    // Wait until both reset signals are released.
    begin
      wait (
        (vif.wrst_n === 1'b1) &&
        (vif.rrst_n === 1'b1)
      );

      reset_released = 1'b1;
    end

    // Thread 2:
    // Timeout protection.
    begin
      #reset_timeout;
    end

  join_any

    // Stop whichever thread did not complete first.
  disable fork;

  // If timeout occurred before reset release, terminate with a clear message.
  if (!reset_released) begin
    `uvm_fatal(
      "RESET_TIMEOUT",
      $sformatf(
        "Initial reset was not released within %0t. wrst_n=%0b, rrst_n=%0b",
        reset_timeout,
        vif.wrst_n,
        vif.rrst_n
      )
    )
  end
  
    // Allow write-domain reset logic to settle.
    @(posedge vif.wclk);

    // Allow read-domain reset logic to settle.
    @(posedge vif.rclk);
    
    `uvm_info(
      "BASE_TEST",
      "Initial write and read resets have been released",
      UVM_LOW
    )

  endtask

//--------------------------------------------------------------------------
  // check_initial_reset_state
  //
  // Common helper task to check expected FIFO status after reset release.
//--------------------------------------------------------------------------
task check_initial_reset_state();

    if (vif.wfull !== 1'b0) begin
      `uvm_error(
        "BASE_TEST",
        $sformatf("Reset check failed: expected wfull=0, actual wfull=%0b",
                  vif.wfull)
      )
    end

    if (vif.awfull !== 1'b0) begin
      `uvm_error(
        "BASE_TEST",
        $sformatf("Reset check failed: expected awfull=0, actual awfull=%0b",
                  vif.awfull)
      )
    end

     if (vif.rempty !== 1'b1) begin
      `uvm_error(
        "BASE_TEST",
        $sformatf("Reset check failed: expected rempty=1, actual rempty=%0b",
                  vif.rempty)
      )
    end

    if (vif.arempty !== 1'b0) begin
      `uvm_error(
        "BASE_TEST",
        $sformatf("Reset check failed: expected arempty=0, actual arempty=%0b",
                  vif.arempty)
      )
    end
    `uvm_info(
      "BASE_TEST",
      $sformatf(
        "Reset state checked: wfull=%0b awfull=%0b rempty=%0b arempty=%0b",
        vif.wfull,
        vif.awfull,
        vif.rempty,
        vif.arempty
      ),
      UVM_LOW
    )

  endtask

endclass
