module kuznechik_cipher_wrapper(
    input               p_clk_i,
    input               p_rstn_i,
    input       [31:0]  p_dat_i,
    input               p_sel_i,
    input               p_enable_i,
    input               p_we_i,
    input       [31:0]  p_adr_i,
    input       [3:0]   p_strb_i,

    output  reg [31:0]  p_dat_o,
    output              p_ready_o,
    output              p_err_o
);

    /* To kuznechik_cipher */
    logic   [127:0] data_r;     // Data from kuznechik_cipher
    logic           busy_r;
    logic           valid_r;

    logic   [127:0] data_w;     // Data to kuznechik_cipher
    logic   [1:0]   req_ack_w;  // kuznechik_cipher activation signal
    logic           rstn_apb_w; // System bus reset signal

    logic           rstn = p_rstn_i & rstn_apb_w;

    kuznechik_cipher kuznechik_cipher(
        .clk_i      (p_clk_i),
        .resetn_i   (rstn),

        .request_i  (req_ack_w[1]),
        .ack_i      (req_ack_w[0]),
        .data_i     (data_w),

        .busy_o     (busy_r),
        .valid_o    (valid_r),
        .data_o     (data_r)
    );


    /* Generating a read/write strobe on the system bus */
    logic prev_enable_ff;
    logic rw_strobe = p_enable_i & ~prev_enable_ff;

    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i)
            prev_enable_ff <= '0;
        else
            prev_enable_ff <= p_enable_i;
    end


    /* Generating enable signal */
    assign p_ready_o = p_enable_i;
    

    /* Error handling */
    logic valid_req;

    always_comb begin
        if ((p_adr_i[5:0] == 6'd0  &&  p_we_i && !(p_strb_i | 4'b1100)) ||
            (p_adr_i[5:0] == 6'd0  && ~p_we_i) ||

            (p_adr_i[5:0] == 6'd4  &&  p_we_i) ||
            (p_adr_i[5:0] == 6'd8  &&  p_we_i) ||
            (p_adr_i[5:0] == 6'd12 &&  p_we_i) ||
            (p_adr_i[5:0] == 6'd16 &&  p_we_i) ||

            (p_adr_i[5:0] == 6'd20 && ~p_we_i) ||
            (p_adr_i[5:0] == 6'd24 && ~p_we_i) ||
            (p_adr_i[5:0] == 6'd28 && ~p_we_i) ||
            (p_adr_i[5:0] == 6'd32 && ~p_we_i) ||
        )
            valid_req = 1;
        else
            valid_req = 0;
    end 

    assign p_err_o = ~valid_req & p_ready_o;


    /* Reading from registers */
    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i)
            p_dat_o <= '0;
        else if (rw_strobe & ~p_we_i) begin
            case (p_adr_i[6:0])
                6'd0 :   p_dat_o[31:0] <= { { 7'b0, busy_r }, {7'b0, valid_r}, 16'b0 };
                6'd20:   p_dat_o[31:0] <= data_r[31:0];
                6'd24:   p_dat_o[31:0] <= data_r[63:32];
                6'd28:   p_dat_o[31:0] <= data_r[95:64];
                6'd32:   p_dat_o[31:0] <= data_r[127:96];
                default: p_dat_o[31:0] <= '0;
            endcase 
        end
    end


    /* Writing to registers */
    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i)
            data_w <= '0;
        // TODO
    end

    logic rst_req     = valid_req & rw_strobe & p_we_i & p_adr_i[5:0] == 0 & (p_strb_i & 4'b0001);
    logic req_ack_req = valid_req & rw_strobe & p_we_i & p_adr_i[5:0] == 0 & (p_strb_i & 4'b0010);

    assign rstn_apb_w = rst_req     ? p_dat_i[0]   :  1;
    assign req_ack_w  = req_ack_req ? p_dat_i[1:0] : '0;

endmodule