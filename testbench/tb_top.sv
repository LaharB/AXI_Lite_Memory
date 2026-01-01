class transaction;

    randc bit op; //operation mode - op = 1(write) , 0(read)
    rand bit [31:0] awaddr;
    rand bit [31:0] wdata;
    rand bit [31:0] araddr;
    //rest of the input signals , we will be forcing from the driver itself     
         bit [31:0] rdata; //from S to M
         bit [1:0] bresp; //from S to M
         bit [1:0] rresp; //from S to M

    //constraints 
    constraint valid_addr_range {awaddr == 1; araddr == 1;}
    constraint valid_data_range {wdata < 12; rdata < 12;}

endclass
//////////////////////////////////////////////////////////////////////////
class generator;

    transaction tr;
    mailbox #(transaction) mbxgen2drv; //to send packet to driver
    
    event done; //gen triggers it when all the iterations of transaction are randomized
    event sconext; //sco triggers it after checking every response

    int count = 0; //to keep count of the number of randomizations

    //new method - constructor
    function new( mailbox #(transaction) mbxgen2drv); //argument that it takes from tb_top and connects to the mbx inside gen and drv
      this.mbxgen2drv = mbxgen2drv; //passing mailbox from tb_top to gen mbx
      tr = new();
    endfunction

    //task to randomize the data and send to drv
    task run();
        for(int i = 0; i < count; i++)
          	
            begin
                assert(tr.randomize) else $error("Randomization Failed");
                $display("[GEN] : OP : %0b awaddr : %0d wdata : %0d araddr : %0d", tr.op, tr.awaddr, tr.wdata, tr.araddr);
                mbxgen2drv.put(tr);//put the trans packet into the mbx
                @(sconext); //wait for sconext trigger from sco
            end
    //once all the iterations done , trigger done 
    ->done;
    
    endtask

endclass
//////////////////////////////////////////////////////////////////////
class driver;

    transaction tr; //data container to store packet sent by gen
    virtual axi_if vif; //giving access of interface to driver 

    mailbox #(transaction) mbxgen2drv;
    mailbox #(transaction) mbxdrv2mon;

    //constructor new()
    function new(mailbox #(transaction) mbxgen2drv, mailbox #(transaction) mbxdrv2mon);
        this.mbxgen2drv = mbxgen2drv;
        this.mbxdrv2mon = mbxdrv2mon;
    endfunction

    ///1.reset the DUT
    task reset();
        vif.resetn <= 0;  //active low reset
        vif.awvalid <= 0;
        vif.awaddr <= 0;
        vif.wvalid <= 0;
        vif.wdata <= 0;
        vif.bready <= 0; //M to S
        vif.arvalid <= 0;
        vif.araddr <= 0; 
        repeat(5) @(posedge vif.clk); //apply reset for  clk ticks
        vif.resetn <= 1;
        $display("----------------[DRV] : RESET DONE--------------");
    endtask

    //3.task for write op
    task write_data(input transaction tr);
      $display("[DRV] : OP : %0b awaddr : %0d wdata : %0d", tr.op, tr.awaddr, tr.wdata);
        mbxdrv2mon.put(tr); //send the same packet to monitor
        vif.resetn <= 1'b1; //remove reset as we need to write 
        vif.awvalid <= 1'b1; 
        vif.arvalid <= 1'b0; //make arvalid = 0 as write oper 
        vif.araddr <= 0; //0 as we are giving write address for write oper
        vif.awaddr <= tr.awaddr; //randomized packet data

        //wait for slave to send awready
        @(negedge vif.awready); //from S to M 
        vif.awvalid <= 1'b0; //make awvalid 0 
        vif.awaddr <= 0; //make awaddr also 0
        //
        vif.wvalid <= 1'b1;
        vif.wdata  <= tr.wdata; //give wdata to DUT

        //wait for slave to send wready 
        @(negedge vif.wready); 
        vif.wvalid <= 1'b0;
        vif.wdata <= 0; //make wvalid and wdata 0
        //
        vif.bready <= 1'b1; //from M to S 
        vif.rready <= 1'b0; //from M to S, making it 0 as write oper

        //wait for slave to give bvalid
        @(negedge vif.bvalid);
        vif.bready <= 1'b0; //from M to S, make it 0 
    endtask
    //bresp will be observed in monitor

    //4.task for read op
    task read_data(input transaction tr);
        $display("[DRV] : OP : %0b araddr : %0d", tr.op, tr.araddr);
        mbxdrv2mon.put(tr); //send the same packet to monitor
        vif.resetn <= 1'b1; //remove reset for read oper
        vif.awvalid <= 0; //disable write 
        vif.awaddr <= 0; 
        vif.wvalid <= 0;
        vif.wdata <= 0;
        vif.arvalid <= 1'b1; //read oper
        vif.araddr <= tr.araddr; 
        //wait for slave to send arready
        @(negedge vif.arready); //S to M
        vif.arvalid <= 1'b0;
        vif.araddr <= 0; //make them 0 as no need anymore
        vif.rready <= 1'b1; //M to S 
        //wait for slave to send rvalid 
        @(negedge vif.rvalid);
        vif.rready <= 1'b0; //make it 0 as job done
    endtask
    //rresp will be observed in monitor

    //2.task to get packet sent by gen
    task run();
        forever 
        begin //forever block used because driver needs to be ready all the time to receive data
            mbxgen2drv.get(tr); // no need of new() for tr as get method does it automatically
            @(posedge vif.clk); //wait for 1 clk tick
            ///check oper mode and call either write or read task
            if(tr.op == 1)
                write_data(tr);
            else
                read_data(tr);
        end
    endtask
endclass
//////////////////////////////////////////////////////////////////////////////
class monitor;

    transaction tr, trd; //trd - data container to store packet from driver
    virtual axi_if vif; //giving access of interface to monitor
    mailbox #(transaction) mbxmon2sco;
    mailbox #(transaction) mbxdrv2mon;
    
    //constructor
    function new(mailbox #(transaction) mbxmon2sco, mailbox #(transaction) mbxdrv2mon);
        this.mbxmon2sco = mbxmon2sco; //connecting the mailboxes from tb_top to these mailboxes
        this.mbxdrv2mon = mbxdrv2mon;
    endfunction

    //task to get DUT response
    task run();

        tr = new(); //object creation for tr instance 
        forever //using forever because mon needs to be ready all the time for sampling DUT response
            begin
                @(posedge vif.clk); //to maintain same delay as driver
                mbxdrv2mon.get(trd); //get the packet from driver
            //if trd.op = 1, sample awaddr and wdata sent by driver and bresp by DUT 
                if(trd.op == 1)
                    begin
                        tr.op = trd.op;
                        tr.awaddr = trd.awaddr;
                        tr.wdata = trd.wdata;
                        //wait for slave to give write response
                        @(posedge vif.bvalid) //S to M
                        tr.bresp = vif.bresp;
                        @(negedge vif.bvalid); ////to maintain same delay as driver
                        $display("[MON] : OP : %0b awaddr : %0d wdata : %0d bresp : %0d", tr.op, tr.awaddr, tr.wdata, tr.bresp);
                        mbxmon2sco.put(tr); //send packet to scoreboard
                    end
                //if tr.op == 0, read the araddr, rdata & rresp sent from DUT
                else
                    begin
                        tr.op = trd.op;
                        tr.araddr = trd.araddr;
                        //wait for S to give response for read op
                        @(posedge vif.rvalid);
                        tr.rdata = vif.rdata;
                        tr.rresp = vif.rresp;
                        @(negedge vif.rvalid); //to maintain same delay as driver
                        $display("[MON] OP : %0b araddr : %0d rdata : %0d rresp : %0d", tr.op, tr.araddr, tr.rdata, tr.rresp);
                        mbxmon2sco.put(tr); //send packet to scoreboard
                    end
            end
    endtask
endclass
//////////////////////////////////////////////////////////////////////////////
class scoreboard;

    transaction tr;
    event sconext; //event to tell gen to send randomize and send next packet 
    mailbox #(transaction) mbxmon2sco;

    //temp variables
    bit [31:0] data[128] = '{default:0}; //data array will store wdata at awaddr location what is written duing write operation
    bit [31:0] temp; //temp will store the data extracted from data[raddr] during read operation

    //constructor new()
    function new(mailbox #(transaction) mbxmon2sco); //connecting mailbox from tb_top to this 
        this.mbxmon2sco = mbxmon2sco;
    endfunction

    //task to compare what is written into memory and what is read 
    task run();
        forever 
            begin
                mbxmon2sco.get(tr);
                if(tr.op == 1)
                    begin
                        $display("[SCO] : OP : %0b awaddr : %0d wdata : %0d bresp : %0d", tr.op, tr.awaddr, tr.wdata, tr.bresp);
                        if(tr.bresp == 3) //bresp = 3 - DECODE ERROR
                            $display("[SCO] : DECODE ERROR");
                        else
                            begin
                                data[tr.awaddr] = tr.wdata;
                                $display("[SCO] : DATA STORED, ADDR : %0d and DATA : %0d", tr.awaddr, tr.wdata);
                            end
                    end
                else
                    begin
                        $display("[SCO] : OP : %0b araddr : %0d rdata : %0d rresp : %0d", tr.op, tr.araddr, tr.rdata, tr.rresp);
                        temp = data[tr.araddr];
                        if(tr.rresp == 3)
                            $display("[SCO] : DECODE ERROR");
                        else if(tr.rresp == 0 && tr.rdata == temp) //tr.rdata is given by DUT, temp contains data written in the same location during write op
                            $display("[SCO] : DATA MATCHED");
                        else
                            $display("[SCO] : DATA MISMATCHED");
$display("---------------------------------------------------------------------");
                    end
            
                ->sconext; //trigger sconext for gen
            end
    endtask
endclass




//////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps 
// `include "interface.sv"
// `include "transaction.sv"
// `include "generator.sv"
// `include "driver.sv"
// `include "monitor.sv"
// `include "scoreboard.sv"

// //tb_top acts as master
module tb_top;

    //create instances of the components
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;

    //conencting the events between components
    //generator and scoreboard common event is sconext 
    event nextgs;

    //connecting mailboxes between components
    mailbox #(transaction) mbxgen2drv, mbxmon2sco, mbxdrv2mon;

    //interface instance
    axi_if vif(); // have to give parenthesis for interface  inside tb

    //connecting int and dut
    axiLite_slave DUT(
        .s_axi_aclk(vif.clk),
        .s_axi_aresetn(vif.resetn),
        //AW
        .s_axi_awvalid(vif.awvalid),
        .s_axi_awready(vif.awready),
        .s_axi_awaddr(vif.awaddr),
        //W
        .s_axi_wvalid(vif.wvalid),
        .s_axi_wready(vif.wready),
        .s_axi_wdata(vif.wdata),
        //B
        .s_axi_bready(vif.bready),
        .s_axi_bvalid(vif.bvalid),
        .s_axi_bresp(vif.bresp),
        //AR
        .s_axi_arvalid(vif.arvalid),
        .s_axi_arready(vif.arready),
        .s_axi_araddr(vif.araddr),
        //R
        .s_axi_rvalid(vif.rvalid),
        .s_axi_rready(vif.rready),
        .s_axi_rdata(vif.rdata),
        .s_axi_rresp(vif.rresp)
    );

    //initialize
    initial begin
        vif.clk <= 0;
    end

    //clk generation
    always #5 vif.clk = ~vif.clk; //100Mhz

    initial begin

        //constructor + connecting with different components
        mbxgen2drv = new();
        mbxmon2sco = new();
        mbxdrv2mon = new();
        gen = new(mbxgen2drv);
        drv = new(mbxgen2drv, mbxdrv2mon);
        mon = new(mbxmon2sco, mbxdrv2mon);
        sco = new(mbxmon2sco);

        //setting generator randomization for 10 times
        gen.count = 10;
        
        //connecting interface with drv and mon
        drv.vif = vif;
        mon.vif = vif;

        //connecting common event between gen and sco
        gen.sconext = nextgs;
        sco.sconext = nextgs;
    end

    //calling run tasks of components
    initial begin
        drv.reset(); //DUT reset
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
        wait(gen.done.triggered);
        $finish;
    end

    //for waveform dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end

endmodule 