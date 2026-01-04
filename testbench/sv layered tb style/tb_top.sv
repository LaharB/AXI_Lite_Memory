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