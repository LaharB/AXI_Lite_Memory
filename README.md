# UVM_Verification_of_Combinational_Adder
This repo shows the verification of a 4-bit combinational adder using Universal Verification Methodology(UVM)

## Code

<details><summary>RTL/Design Code</summary>

```systemverilog
///////DUT + Interface 
module add(
  input [3:0]a,b,
  output [4:0]y
);
  
assign y = a + b;
  
endmodule

/////////////////////////////////////////

interface add_if();
  logic [3:0]a;
  logic [3:0]b;
  logic [4:0]y;
  
endinterface
```
</details>

__________________________________________________________

<details><summary>Testbench Code</summary>

```systemverilog

`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

/////        TRANSACTION          //////
class transaction extends uvm_sequence_item;  //dynamic component

  //data members
  rand bit [3:0]a;
  rand bit [3:0]b;
  bit [4:0]y;
   
  function new(input string path = "transaction");   //1 arg\
    super.new(path);
  endfunction
  
  //register the data members with field macros to use automation
  `uvm_object_utils_begin(transaction);
  `uvm_field_int(a, UVM_DEFAULT);
  `uvm_field_int(b, UVM_DEFAULT);
  `uvm_field_int(y, UVM_DEFAULT);
  `uvm_object_utils_end
  
endclass
////////////////////////////////////////////////////////////////////
//////sequence but we are naming it as generator///////////////
//////////  GENERATOR /////////////
class generator extends uvm_sequence #(transaction); //dynamic component 
  `uvm_object_utils(generator)
 
  transaction trans;
    
    function new(input string path = "generator"); //dynamic component 
    super.new(path);
  endfunction
  
  //task to randomize 
  virtual task body();
   //make trans object
    trans = transaction::type_id::create("trans");  //1 arg for create() as dynamic component 
    repeat(10)begin
      start_item(trans);
      trans.randomize();
      `uvm_info("SEQ", $sformatf("Data sent to driver a: %0d, b: %0d",trans.a, trans.b), UVM_NONE);
      finish_item(trans);
    end  
  endtask
  
endclass
//////////////////////////////////////////////////////////////////////////
//we dont need any separate class for sequencer, go for driver directly
/////   DRIVER   /////
class driver extends uvm_driver #(transaction); //static component   
 `uvm_component_utils(driver)
  
  function new(input string path = "driver", uvm_component parent = null); //2 args as static component
    super.new(path, parent);
  endfunction
  
  transaction tc; //a transaction container tc to hold what we receive from sequence
  virtual add_if aif; //interface handle to give driver access to driver
  
  //build_phase 
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tc = transaction::type_id::create("tc", this);
    
    //confid_db & get to give driver access to the interface 
    if(!uvm_config_db#(virtual add_if)::get(this,"","aif", aif))
     `uvm_error("DRV", "Unable to access uvm_config_db");
    endfunction
  
    //task to communicate between driver and sequencer
  virtual task run_phase(uvm_phase phase);
    //using a forever block so that driver is always ready for getting trans
    forever begin
      seq_item_port.get_next_item(tc); //gets the trans packet that is kept ready by generator(sequence)
      
      //apply them to the DUT through the interface 
      aif.a <= tc.a;
      aif.b <= tc.b;
      `uvm_info("DRV", $sformatf("Trigger DUT a: %0d, b: %0d", tc.a, tc.b), UVM_NONE);
      seq_item_port.item_done();
      #10;  //wait for 10 secs so that the inputs have enought ime to be applied to the DUT
    end
  endtask
  
endclass
/////////////////////////////////////////////////////////////////////////////////
///////    MONITOR   ///////////
class monitor extends uvm_monitor;    //static component - uvm_component
 `uvm_component_utils(monitor)
  
  //uvm_analysis port to send data captured from interface to scoreboard
  uvm_analysis_port #(transaction) send;
  
  function new(input string path = "monitor", uvm_component parent = null);
    super.new(path, parent);  //2 args 
    //also construct the port "send" inside new() itself 
    send = new("send", this);
  endfunction
  
  transaction t;
  virtual add_if aif;
  
  //build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    t = transaction::type_id::create("t"); //1 arg for create() as belongs uvm_object
    
    //config_db and get method to give monitor access to interface 
    if(!uvm_config_db #(virtual add_if)::get(this,"","aif", aif))
      `uvm_error("MON", "Unable to access uvm_config_db");
  endfunction
  
  //task run_phase to pass data and response from interface to monitor
  virtual task run_phase(uvm_phase phase);
    forever begin
      #10;   //wait for #10 more so that driver gets enough time to send the data to the interface and then start passing that data and response to the monitor 
     t.a = aif.a;
     t.b = aif.b;
     t.y = aif.y;
     `uvm_info("MON", $sformatf("Data Sent to Scoreboard a: %0d, b: %0d, y: %0d",t.a, t.b, t.y), UVM_NONE);
      //send method 
      send.write(t);  // send transaction t to scoreboard
    end
  endtask
    
endclass
////////////////////////////////////////////////////////////////////////////////
///////////   SCOREBOARD    //////////////////////////////////
class scoreboard extends uvm_scoreboard;
 `uvm_component_utils(scoreboard)
  
  //uvm_analysis implementation to get the data from monitor
  uvm_analysis_imp #(transaction, scoreboard) recv; 
   
  transaction tr; //transaction container 
  
  function new(input string path = "scoreboard", uvm_component parent = null);
    super.new(path, parent);
    //construct the recv port inside new() itself
    recv = new("recv", this);
  endfunction

  //build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr = transaction::type_id::create("tr"); //1 arg as belongs to uvm_object
  endfunction
  
  //function write to get data from monitor
  virtual function void write(transaction t);
    tr = t;   //we are what we get from monitor in t to the container tr in scorebaord
    `uvm_info("SCO", $sformatf("Data rcvd from Monitor a: %0d, b: %0d, y: %0d", tr.a, tr.b, tr.y), UVM_NONE);
    
    //check data and response using own logic
    if(tr.y == tr.a + tr.b)
      `uvm_info("SCO", "Test Passed", UVM_NONE)
    else 
      `uvm_info("SCO", "Test Failed", UVM_NONE);
  endfunction     
  
endclass
////////////////////////////////////////////////////////////////////////////////
///////  AGENT ////////////////
class agent extends uvm_agent;
 `uvm_component_utils(agent)
  
  function new(input string path = "agent", uvm_component parent = null);
    super.new(path, parent);
  endfunction
  
  //agent contains sequencer, driver and monitor 
  uvm_sequencer#(transaction) seqr;
  driver d;
  monitor m;
  
  //build_phase 
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    //2 args as belongs to uvm_component for the below 
    seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
    d = driver::type_id::create("d", this);
    m = monitor::type_id::create("m", this);
  endfunction
  
  //connect phase to connect the sequencer with driver inside agent 
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    d.seq_item_port.connect(seqr.seq_item_export); //connected them
  endfunction

endclass
/////////////////////////////////////////////////////////////////////////////////
////////   ENVIRONMENT /////////////
class env extends uvm_env;
 `uvm_component_utils(env)
  
  //env contains agent and scoreboard
  agent a;
  scoreboard s;
    
  function new(input string path = "env", uvm_component parent = null);
    super.new(path, parent);  
  endfunction
  
  //build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a = agent::type_id::create("a", this);
    s = scoreboard::type_id::create("e", this);
  endfunction
  
  //connect phase to connect scoreboard and monitor inside env
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a.m.send.connect(s.recv);  //connected monitor with scoreboard
  endfunction
  
endclass
////////////////////////////////////////////////////////////////////////////
///////   TEST //////////////
class test extends uvm_test;
  `uvm_component_utils(test)
 
  function new(input string path = "test", uvm_component parent = null);
    super.new(path, parent);
  endfunction
  
  //env is inside test
  env e;
  generator gen; //or sequence seq if we named our class "sequence" instead of "generator"
  
  //build_phase 
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e = env::type_id::create("e", this);
    gen = generator::type_id::create("gen");
  endfunction
  
  //task run_phase to start the sequence
  virtual task run_phase(uvm_phase phase);
    //to hold the simulator
    phase.raise_objection(this);
    gen.start(e.a.seqr);  //seq.start(e.a.seqr);
    #50;
    phase.drop_objection(this);
  endtask

endclass
/////////////////////////////////////////////////////////////////////////////////
//////// TESTBENCH_TOP //////////////
module tb;
  
//inside tb , we have interface , DUT and test class
  add_if aif();  //have to add parenthesis for interface instance
  add dut(.a(aif.a), .b(aif.b), .y(aif.y));   //connections between DUT and test class through interface 
  
  //we dont need to make a seperate object for test unlike SV, we directly use run_test
  initial begin
   //config_db and set method to give access of the interface to driver and monitor 
    uvm_config_db #(virtual add_if)::set(null, "uvm_test_top.e.a*", "aif", aif);
    run_test("test");
  end
  
  //to see waveform
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end 
  
endmodule
```
</details>

__________________________________________________________

<details><summary>Simulation</summary><br>

![alt text](<Sim/UVM Based Combinational Adder P1.png>)
![alt text](<Sim/UVM Based Combinational Adder P2.png>)
![alt text](<Sim/UVM Based Combinational Adder P3.png>)

</details>

__________________________________________________________

<details><summary>Waveform</summary><br>

![alt text](<Sim/UVM Based Combinational Adder Waveform.png>)

</details>