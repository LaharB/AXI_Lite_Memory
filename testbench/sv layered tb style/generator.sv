class generator;

    transaction tr;
    mailbox #(transaction) mbxgen2drv; //to send packet to driver
    
    event done; //gen triggers it when all the iterations of transaction are randomized
    event sconext; //sco triggers it after checking every response

    int count = 0; //to keep count of the number of randomizations

    //new method - constructor
    function new( mailbox #(transaction) mbxgen2drv); //argument that it takes from tb_top and connects to the mbx inside gen and drv
        this.mbxgen2drv = mbxgen2drv; //passing mailbox from tb_top to gen mbx       
    endfunction

    //task to randomize the data and send to drv
    task run();
        for(int i = 0; i < count; i++)
            begin
                tr = new(); //object crration for tr 
                assert(tr.randomize) else $error("Randomization Failed");
                $display("[GEN] : OP : %0b awaddr : %0d wdata : %0d araddr : %0d", tr.op, tr.awaddr, tr.wdata, tr.araddr);
                mbxgen2drv.put(tr);//put the trans packet into the mbx
                @(sconext); //wait for sconext trigger from sco
            end
    //once all the iterations done , trigger done 
    ->done;
    
    endtask

endclass