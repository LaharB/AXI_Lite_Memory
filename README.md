# Verification_of_AXI_Lite_Memory
This project showcases the verification of an AXI_Lite Memory using 
1.Verilog style testbench architecture
2.System verilog Layered testbench architecture
where the design is acting as axi_slave and testbench is acting as axi_master.
The design does not implement burst transfer or wstrb signals.

The AXI_lite memory is designed and simulated using AMD Vivado 2025.1 tool.

## Code

<details><summary>RTL/Design Code</summary>

```systemverilog
//design code is the axi_slave and tb code will act like axi_master
module axiLite_slave(
    input s_axi_aclk,
    input s_axi_aresetn, //active low reset 
    
    //Address Write Channel(AW) - for writing address 
    //valid signal is always given by Sender, ready signal is always given by Receiver
    input s_axi_awvalid, //M to S (from sender to receiver)
    output reg s_axi_awready, //S to M
    input [31:0] s_axi_awaddr,  //M to S    //32-bit address size

    //Write Data Channel(W) - for writing data 
    input s_axi_wvalid, //M to S
    output reg s_axi_wready, //S to M
    input [31:0] s_axi_wdata, //32-bit data size

    //Write Response channel(B)- for response of write transaction
    output reg s_axi_bvalid, //S to M
    input s_axi_bready, //M to S
    output reg [1:0] s_axi_bresp, //S to M 00 - Okay , 11 - Decode error

    //Address Read channel(AR) - for reading from address
    input s_axi_arvalid, //M to S
    output reg s_axi_arready, //S to M
    input [31:0] s_axi_araddr, //M to S 32-bit address size
    
    //Read Data Channel(R) - for reading data from that address sent by M to S
    output reg s_axi_rvalid, //S to M
    input s_axi_rready, //M to S
    output reg [31:0] s_axi_rdata, //S to M 32 bit data from the address sent by M to S
    output reg [1:0] s_axi_rresp //S to M  00 - Okay , 11 - Decode Error
);

localparam idle = 0, //store the awaddr 
           send_waddr_ack = 1,//, make s_axi_awvalid high and get awready from slave
           send_raddr_ack = 2,//store the raddr, make s-axi_rvalid high and also get rready from slave
           send_wdata_ack = 3, //store the data, make s-axi_rvalid high and get the rready from slave
           update_mem = 4, //update the 32-bit x 128 memory
           send_wr_err = 5,
           send_wr_resp = 6, //response by slave
           gen_data = 7, //check addr value < 128 
           send_rd_err = 8,
           send_rd_resp = 9; //response by slave 

reg [3:0] state = idle;  //4-bits as states from 0 to 9
reg [3:0] next_state = idle;
reg [1:0] count = 0; //var used to wait for 2 clk ticks
reg [31:0] waddr, raddr, wdata, rdata; //32-bit temp reg to store info

reg [31:0] mem[128]; //slave memeory

always@(posedge s_axi_aclk)
begin
    if(s_axi_aresetn == 1'b0) 
    begin
        state <= idle;
        //intialize the memory
        for(int i = 0; i <128; i++)
        begin
            mem[i] <= 0;
        end 
        //make some control signals zero
        s_axi_awready <= 0;

        s_axi_wready <= 0;

        s_axi_bvalid <= 0;
        s_axi_bresp <= 0;

        s_axi_arready <= 0;

        s_axi_rvalid <= 0;
        s_axi_rdata <= 0;
        s_axi_rresp <= 0;

        //make temp regsiters zero
        waddr <= 0;
        raddr <= 0;
        wdata <= 0;
        rdata <= 0;
    end

    else
    begin
        case(state)

        idle:
        begin
            s_axi_awready <= 0;
            s_axi_wready <= 0;
            s_axi_bvalid <= 0;
            s_axi_bresp <= 0;
            s_axi_arready <= 0;
            s_axi_rvalid <= 0;
            s_axi_rdata <= 0;
            s_axi_rresp <= 0;
            s_axi_rvalid <= 0;
            
            waddr <= 0;
            raddr <= 0;
            wdata <= 0;
            rdata <= 9;
            count <= 0;
            
        if(s_axi_awvalid == 1'b1)  //write operation , M to S
            begin
                state <= send_waddr_ack;
//as soon as s_axi_awvalid is high, we make axi_awready high and handshake happens and data transfer happens 
                s_axi_awready <= 1'b1;  // S to M , make awready 1 
                waddr <= s_axi_awaddr;  //store the write address in temp reg from s_axi_awaddr line
            end     
        else if(s_axi_arvalid == 1'b1)  //read operation
            begin
                state <= send_raddr_ack;
                s_axi_arready <= 1'b1;  //S to M, make arready 1 as soon as arvalid = 1
                raddr <= s_axi_araddr; //store the read address in temp reg
            end
        else 
            begin
                state <= idle;
            end
        end

        //write operation 
        /////////////////////////////////////////////////////////////////
        send_waddr_ack:
        begin
            s_axi_awready <= 1'b0; //make awready 0
            if(s_axi_wvalid) //M to S, storing awdata into wdata temp reg
                begin
                wdata <= s_axi_wdata; //store data in the temp reg
                s_axi_wready <= 1'b1; //make awready = 1 for handshake
                state <= send_wdata_ack;     
                end
            else 
                begin
                    state <= send_waddr_ack;
                end

        end

        send_wdata_ack:
        begin
            s_axi_wready <= 1'b0; //make wready 0
            if(waddr < 128)  //check address range 
                begin
                    state <= update_mem;
                    mem[waddr] <= wdata; 
                end
            else
                begin
                    state <= send_wr_err;
                    s_axi_bresp <= 2'b11; //error response
                    s_axi_bvalid <= 1'b1;
                end

        end

        update_mem:
        begin
            mem[waddr] <= wdata;
            state <= send_wr_resp;
        end

        send_wr_resp:
        begin
            s_axi_bresp <= 2'b00; //00 Okay Response
            s_axi_bvalid <= 1'b1; //S to M
            if(s_axi_bready) //M to S , waiting for bready from master
                begin        
                    state <= idle;
                end
            else
                begin
                    state <= send_wr_resp;            
                end
            
        end

        send_wr_err:
        begin
            if(s_axi_bready) //M to S, , waiting for bready from master
                begin
                   state <= idle; 
                end
            else 
                begin
                    state <= send_wr_err; //stay in send_wr_err
                end
            
        end

        //////////////////////////////////////////////////////////////////

        //read operation
        //////////////////////////////////////////////////////////////////
        send_raddr_ack:
        begin
            s_axi_arready <= 0; //make it 0 as already made 1 when arvalid was 1
            if(raddr < 128)
                state <= gen_data;
            else
                begin
                    s_axi_rvalid <= 1'b1;  //S to M
                    state <= send_rd_err;
                    s_axi_rdata <= 0;
                    s_axi_rresp <= 2'b11;  //error response
                end
        end

        gen_data: 
        begin
            if(count < 2)
                begin
                    rdata <= mem[raddr];  //put the data in temp reg and wait for 2 clk ticks 
                    state <= gen_data;
                    count <= count + 1;
                end
            else
            //wait for master response now
                begin
                    s_axi_rvalid <= 1'b1;  //S to M
                    s_axi_rdata <= rdata;
                    s_axi_rresp <= 2'b00; //No error
                    if(s_axi_rready)  //M to S
                        state <= idle; //go back to idle if s_axi_aready sent by M
                    else
                        state <= gen_data;
                end
        end

        send_rd_err:
        begin
            if(s_axi_rready) //M to S
                begin
                    state <= idle;
                end
            else 
                begin
                    state <= send_rd_err;
                end 
        end
        //////////////////////////////////////////////////////////////////
        default : state <= idle;

        endcase
    end
end

endmodule
```
</details>

__________________________________________________________

<details><summary>Testbench Code</summary>

### Verilog Based Testbench

```systemverilog

//tb acts as axiLite_master
`timescale 1ns / 1ps
module axiLite_tb;

    reg tb_s_axi_aclk = 0;
    reg tb_s_axi_aresetn = 0;
    //AW
    reg tb_s_axi_awvalid = 0;
    wire tb_s_axi_awready;
    reg [31:0] tb_s_axi_awaddr = 0;

    //W
    reg tb_s_axi_wvalid = 0;
    wire tb_s_axi_wready;
    reg [31:0] tb_s_axi_wdata = 0;

    //B
    wire tb_s_axi_bvalid;
    reg tb_s_axi_bready = 0;
    wire [1:0] tb_s_axi_bresp;

    //AR
    reg tb_s_axi_arvalid = 0;
    wire tb_s_axi_arready;
    reg [31:0] tb_s_axi_araddr = 0;

    //R
    wire tb_s_axi_rvalid;
    reg tb_s_axi_rready = 0;
    wire [31:0] tb_s_axi_rdata;
    wire [1:0] tb_s_axi_rresp;

    //connect to DUT
    axiLite_slave DUT (
        .s_axi_aclk(tb_s_axi_aclk),
        .s_axi_aresetn(tb_s_axi_aresetn),
        //AW
        .s_axi_awvalid(tb_s_axi_awvalid),
        .s_axi_awready(tb_s_axi_awready),
        .s_axi_awaddr(tb_s_axi_awaddr),
        //W
        .s_axi_wvalid(tb_s_axi_wvalid),
        .s_axi_wready(tb_s_axi_wready),
        .s_axi_wdata(tb_s_axi_wdata),
        //B 
        .s_axi_bvalid(tb_s_axi_bvalid),
        .s_axi_bready(tb_s_axi_bready),
        .s_axi_bresp(tb_s_axi_bresp),
        //AR
        .s_axi_arvalid(tb_s_axi_arvalid),
        .s_axi_arready(tb_s_axi_arready),
        .s_axi_araddr(tb_s_axi_araddr),
        //R
        .s_axi_rvalid(tb_s_axi_rvalid),
        .s_axi_rready(tb_s_axi_rready),
        .s_axi_rdata(tb_s_axi_rdata),
        .s_axi_rresp(tb_s_axi_rresp)

    );

    //clk generation
    always #5 tb_s_axi_aclk = ~tb_s_axi_aclk; //100 Mhz 

    //stimulus
    initial begin
        //reset
        tb_s_axi_aresetn = 0;  //assert reset
        //reset the DUT for 5 clk ticks
        repeat(5) @(posedge tb_s_axi_aclk);
        tb_s_axi_aresetn = 1; //deassert reset

        //write transaction
        //write address
        repeat(2) @(posedge tb_s_axi_aclk); //wait for 2 clk ticks 
        tb_s_axi_awvalid = 1; //M to S
        tb_s_axi_awaddr = 32'h00000005;
        //wait for slave ready
        @(negedge tb_s_axi_awready); //wait for slave to receive it 
        tb_s_axi_awvalid = 0; //make valid from M 0 as handshake is done 

        //write data
        repeat(2) @(posedge tb_s_axi_aclk); //again wait for 2 clk ticks
        tb_s_axi_wvalid = 1; //M to S
        tb_s_axi_wdata = 32'hC0DECAFE; 
        //wait for slave ready
        @(negedge tb_s_axi_wready); //wait for slave to receive it 
        tb_s_axi_wvalid = 0; //make wvalid from M 0 as handshake done

        //write response
        repeat(2) @(posedge tb_s_axi_aclk); //again wait for 2 clk ticks
        //S wait for M to give bready
        tb_s_axi_bready = 1; //M to S
        @(negedge tb_s_axi_bvalid); //wait for slave to send response 
        tb_s_axi_bready = 0; //make bready from M 0 as resp handshake also done

        //read transaction
        //address read
        repeat(2) @(posedge tb_s_axi_aclk); //wait for 2 clk ticks
        tb_s_axi_arvalid = 1; //M to S
        tb_s_axi_araddr = 32'h00000005; //read from the same address
        //wait for slave arready
        @(negedge tb_s_axi_arready); //wait for slave to receive it  
        tb_s_axi_arvalid = 0; //make arvalif from M 0 as handshake done

        //data read 
        @(posedge tb_s_axi_aclk); //again wait for 1 clk tick
        //S wait for M to give rready 
        tb_s_axi_rready = 1;
        @(negedge tb_s_axi_rvalid); //wait for slave to send response 
        tb_s_axi_rready = 0; //make rready from M 0 as handshake done

        //end of test
        #100;
        $stop;
    end

endmodule
```

## SV Layered Tesebench

```systemverilog
/*
//this testbench contains all the classes together
*/

`timescale 1ns / 1ps 
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
```
</details>

____________________________________________________________________________


<details><summary>Simulation</summary><br>

### Handshakes happening in the different channels

![alt text](<sim/AXI_Lite_mem 1 all channel.png>)

### Memory getting updated according to AXI protocol 
![alt text](<sim/AXI_Lite_mem 6 Slave Memory update.png>)

</details>

__________________________________________________________
