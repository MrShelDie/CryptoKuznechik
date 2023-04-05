module kuznechik_chipher_wrapper_tb();

    logic           clk, rstn, select, en, we, ready, error;
    logic   [31:0]  data_i, data_o, addr;
    logic   [3:0]   byte_select;

    initial clk <= 0;
    always #5ns clk <= ~clk;

    kuznechik_cipher_wrapper DUT(
        .p_clk_i    (clk),
        .p_rstn_i   (rstn),
        .p_dat_i    (data_i),
        .p_sel_i    (select),
        .p_enable_i (en),
        .p_we_i     (we),
        .p_adr_i    (addr),
        .p_strb_i   (byte_select),

        .p_dat_o    (data_o),
        .p_ready_o  (ready),
        .p_err_o    (error)
    );

    task rw(input [31:0] addr_, input [3:0] byte_sel_, input [31:0] din_, input we_);
        addr        <= addr_;
        byte_select <= byte_sel_;
        select      <= 1;
        we          <= we_;

        #10;
        en <= 1;
        data_i <= din_;

        @(posedge ready)
        @(posedge clk)

        #1;
        en <= 0;
    endtask

    initial begin
        rstn <= 0;
        select <= 0;
        en <= 0;
        we <= 0;
        data_i <= '0;

        #16 rstn <= 0;
        #30 rstn <= 1;

        #10
        rw('0, 4'b0001, 0, 1);
        rw('0, 4'b0001, 0, 0);
        rw('0, 4'b0001, 0, 1);
        rw('0, 4'b0100, 0, 1);
        rw('0, 4'b0001, 0, 1);

        $finish;
    end

endmodule