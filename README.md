# Verification_of_AXI_Lite_Memory
This repo shows the verification of a AXI_Lite Memory where the design is acting as axi_slave and testbench is acting as axi_master.

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
</details>

__________________________________________________________

<details><summary>Simulation</summary><br>

![alt text](<sim/AXI_Lite_mem 1 all channel.png>)
![alt text](<sim/AXI_Lite_mem 6 Slave Memory update.png>)

</details>

__________________________________________________________
