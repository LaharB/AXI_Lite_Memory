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
    constraint valid_data_range {awdata < 12; rdata < 12;}

endclass