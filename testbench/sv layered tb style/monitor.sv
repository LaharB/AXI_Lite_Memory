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
                //if tr.op == 0, read the araddr, radata & rresp sent from DUT
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