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