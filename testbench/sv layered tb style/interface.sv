interface axi_if;

    logic clk, resetn;

    logic awvalid, awready;
    logic [31:0] awaddr;

    logic wvalid, wready;
    logic [31:0] wdata;

    logic bready, bvalid;
    logic [1:0] bresp;

    logic arvalid, arready;
    logic [31:0] araddr;

    logic rvalid, rready;
    logic [31:0] rdata;
    logic [1:0] rresp;

endinterface