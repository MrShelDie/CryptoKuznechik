module kuznechik_chipher_wrapper_tb();

    localparam  WE_WRITE = 1,
                WE_READ  = 0;

    localparam  BYTESEL_WORD        = 4'b1111,
                BYTESEL_NONE        = 4'b0000,
                BYTESEL_FIRST_BYTE  = 4'b0001,
                BYTESEL_SECOND_BYTE = 4'b0010,
                BYTESEL_THIRD_BYTE  = 4'b0100,
                BYTESEL_FOURTH_BYTE = 4'b1000;


    logic           clk, rstn, select, en, we, ready, error;
    logic   [31:0]  data_i, data_o, addr;
    logic   [3:0]   byte_select;

    logic   [127:0]      result [10:0];
    logic   [128*11-1:0] print_str;

    kuznechik_cipher_wrapper DUT(
        .p_clk_i    (clk),
        .p_rstn_i   (rstn),
        .p_data_i   (data_i),
        .p_sel_i    (select),
        .p_enable_i (en),
        .p_we_i     (we),
        .p_addr_i   (addr),
        .p_strb_i   (byte_select),

        .p_data_o   (data_o),
        .p_ready_o  (ready),
        .p_err_o    (error)
    );


    task rw(input [31:0] addr_, input we_, input [3:0] byte_sel_, input [31:0] din_);
        @(posedge clk);
        addr        <= addr_;
        data_i      <= din_;
        byte_select <= byte_sel_;
        select      <= 1;
        we          <= we_;

        @(posedge clk);
        en <= 1;

        @(posedge ready)
        @(posedge clk)

        en <= 0;
    endtask


    task decode(input [127:0] data_in_, input [7:0] i);
        @(posedge clk);

        /* Load data to be decoded */
        rw(32'd4,  WE_WRITE, BYTESEL_WORD, data_in_[31:0]  );
        rw(32'd8,  WE_WRITE, BYTESEL_WORD, data_in_[63:32] );
        rw(32'd12, WE_WRITE, BYTESEL_WORD, data_in_[95:64] );
        rw(32'd16, WE_WRITE, BYTESEL_WORD, data_in_[127:96]);

        /* Send request to start processing */
        rw(32'd0,  WE_WRITE, BYTESEL_SECOND_BYTE, 32'h2);

        #2000
        rw(32'd20,  WE_READ, BYTESEL_NONE, 32'h2);
        result[i][31:0]   <= data_o[31:0];
        rw(32'd24,  WE_READ, BYTESEL_NONE, 32'h2);
        result[i][63:32]  <= data_o[31:0];
        rw(32'd28,  WE_READ, BYTESEL_NONE, 32'h2);
        result[i][95:64]  <= data_o[31:0];
        rw(32'd32,  WE_READ, BYTESEL_NONE, 32'h2);
        result[i][127:96] <= data_o[31:0];
    endtask


    /* Clock */
    initial begin
        clk <= 0;
        forever
            #5 clk <= ~clk;
    end


    /* Main */
    initial begin
        rstn    <= 0;
        select  <= 0;
        en      <= 0;
        we      <= 0;
        data_i  <= '0;

        #30
        rstn <= 1;
        #30

        /* Reset */
        rw(32'd0,  WE_WRITE, BYTESEL_FIRST_BYTE, 32'h1);

        /* Error check */        
//        rw(32'd0,  WE_WRITE, BYTESEL_THIRD_BYTE, 32'h1);

        decode(128'h3ee5c99f9a41c389ac17b4fe99c72ae4, 8'd0);
        decode(128'h79cfed3c39fa7677b970bb42a5631ccd, 8'd1);
        decode(128'h63a148b3d9774cede1c54673c68dcd03, 8'd2);
        decode(128'h2ed02c74160391fd9e8bd4ba21e79a9d, 8'd3);
        decode(128'h74f245305909226922ac9d24b9ed3b20, 8'd4);
        decode(128'h03dde21c095413db093bb8636d8fc082, 8'd5);
        decode(128'hbdeb379c9326a275c58c756885c40d47, 8'd6);
        decode(128'h2dcabdf6b6488f5f3d56c2fd3d2357b0, 8'd7);
        decode(128'h887adf8b545c4334e0070c63d2f344a3, 8'd8);
        decode(128'h23feeb9115fab3e4f9739578010f212c, 8'd9);
        decode(128'h53e0ebee97b0c1b8377ac5bce14cb4e8, 8'd10);
        
        @(posedge clk);
        $display("Ciphering has been finished.");
        $display("============================");
        $display("===== Ciphered message =====");
        $display("============================");
        print_str = {
            result[0],
            result[1],
            result[2],
            result[3],
            result[4],
            result[5],
            result[6],
            result[7],
            result[8],
            result[9],
            result[10]
        };
        $display("%s", print_str);
        $display("============================");
        $finish;
    end

endmodule