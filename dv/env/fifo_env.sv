//------------------------------------------------------------------------------
// File        : fifo_env.sv
// Description : Top-level UVM environment for asynchronous FIFO verification.
//
// The environment contains:
//
//   - fifo_write_agent : Drives and monitors write-side FIFO activity.
//   - fifo_read_agent  : Drives and monitors read-side FIFO activity.
//   - fifo_scoreboard  : Checks FIFO data integrity and FIFO ordering.
//------------------------------------------------------------------------------
 
 class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)
  
//--------------------------------------------------------------------------
  // Environment Components
//--------------------------------------------------------------------------
   fifo_write_agent wagent;
   fifo_read_agent ragent;
   fifo_sb     sb;
   fifo_coverage_model cm;

//--------------------------------------------------------------------------
  // Constructor
//--------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

//--------------------------------------------------------------------------
  // build_phase 
//--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wagent = fifo_write_agent :: type_id :: create ("wagent", this);
    ragent = fifo_read_agent :: type_id :: create ("ragent", this);
    sb = fifo_sb:: type_id :: create("sb",this);
    cm = fifo_coverage_model:: type_id :: create("cm",this);

endfunction

//--------------------------------------------------------------------------
  // connect_phase 
//-------------------------------------------------------------------------- 
   function void connect_phase(uvm_phase phase);
     super.connect_phase(phase);
     wagent.wmon.wmon_ap.connect(sb.sb_export_write);
     ragent.rmon.rmon_ap.connect(sb.sb_export_read);
     `uvm_info("ENV",$sformatf("Connected Monitor to SB"),UVM_LOW)
     wagent.wmon.wmon_ap.connect(cm.cm_export_write);
     ragent.rmon.rmon_ap.connect(cm.cm_export_read);
     `uvm_info("ENV",$sformatf("Connected Monitor to CM"),UVM_LOW)

   endfunction

 endclass 
