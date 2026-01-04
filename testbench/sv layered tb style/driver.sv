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