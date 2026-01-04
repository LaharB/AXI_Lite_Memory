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