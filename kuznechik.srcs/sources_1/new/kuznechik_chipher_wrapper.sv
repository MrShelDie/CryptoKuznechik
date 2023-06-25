/* All transactions with the kuznechik_chipher module run without delay */

module kuznechik_cipher_wrapper(
    input                p_clk_i,
    input                p_rstn_i,
    input        [31:0]  p_data_i,
    input                p_sel_i,
    input                p_enable_i,
    input                p_we_i,
    input        [31:0]  p_addr_i,
    input        [3:0]   p_strb_i,

    output logic [31:0]  p_data_o,
    output               p_ready_o,
    output               p_err_o
);

    /* To from kuznechik_cipher */
    logic   [127:0] data_w;     // Data to kuznechik_cipher
    logic           req_w;      // Start processing
    logic           ack_w;      // Confirmation of receipt of processed data

    logic           rstn_apb_w; // System bus reset signal
    logic           rstn;

    /* From kuznechik_cipher */
    logic   [127:0] data_r;     // Data from kuznechik_cipher
    logic           busy_r;
    logic           valid_r;


    assign rstn = p_rstn_i & rstn_apb_w;


    kuznechik_cipher kuznechik_cipher(
        .clk_i      (p_clk_i),
        .resetn_i   (rstn),

        .request_i  (req_w),
        .ack_i      (ack_w),
        .data_i     (data_w),

        .busy_o     (busy_r),
        .valid_o    (valid_r),
        .data_o     (data_r)
    );


    /* Generating a read/write strobe on the system bus 
     * The strobe is generated when a p_enable_i signal is set to the bus */
    logic rw_strobe;
    logic prev_enable_ff;

    assign rw_strobe = p_enable_i & ~prev_enable_ff & p_sel_i;

    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i)
            prev_enable_ff <= '0;
        else
            prev_enable_ff <= p_enable_i;
    end


    /* Generating ready signal when p_enable_i signal is set to the bus */
    assign p_ready_o = p_enable_i;
    

    /* Error handling */
    logic valid_req;

    always_comb begin
        if ((p_addr_i[5:0] == 6'd0  &&  p_we_i && (p_strb_i[1] | p_strb_i[0])) ||   // Write to {REQ, ACK} or RST
            (p_addr_i[5:0] == 6'd0  && ~p_we_i && (p_strb_i[3] | p_strb_i[2])) ||   // Read from BUSY or VALID

            // Write to data_in
            (p_addr_i[5:0] == 6'd4  &&  p_we_i) || 
            (p_addr_i[5:0] == 6'd8  &&  p_we_i) ||
            (p_addr_i[5:0] == 6'd12 &&  p_we_i) ||
            (p_addr_i[5:0] == 6'd16 &&  p_we_i) ||

            // Read from data_out
            (p_addr_i[5:0] == 6'd20 && ~p_we_i) ||
            (p_addr_i[5:0] == 6'd24 && ~p_we_i) ||
            (p_addr_i[5:0] == 6'd28 && ~p_we_i) ||
            (p_addr_i[5:0] == 6'd32 && ~p_we_i)
        )
            valid_req = 1;
        else
            valid_req = 0;
    end 

    assign p_err_o = ~valid_req & p_ready_o;


    /* Reading from registers */
    always_comb begin
        case (p_addr_i[5:0])
            6'd0 :   p_data_o[31:0] = { { 7'b0, busy_r }, {7'b0, valid_r}, 16'b0 };
            6'd20:   p_data_o[31:0] = data_r[31:0];
            6'd24:   p_data_o[31:0] = data_r[63:32];
            6'd28:   p_data_o[31:0] = data_r[95:64];
            6'd32:   p_data_o[31:0] = data_r[127:96];
            default: p_data_o[31:0] = '0;
        endcase 
    end


    /* Writing to registers */
    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i)
            data_w <= '0;
        else if (valid_req & rw_strobe & p_we_i) begin
            case (p_addr_i[5:0])
                /* The case of RST and {REQ, ACK} is handled separately below
                 * because RST and {REQ, ACK} are not registers */
                6'd4:    data_w[31:0]   <= p_data_i[31:0];
                6'd8:    data_w[63:32]  <= p_data_i[31:0];
                6'd12:   data_w[95:64]  <= p_data_i[31:0];
                6'd16:   data_w[127:96] <= p_data_i[31:0];
            endcase 
        end
    end


    /* Case of writing to RST or/and {REQ, ACK} */
    logic rst_request;
    logic req_ack_request;

    assign rst_request     = valid_req & rw_strobe & p_we_i & p_addr_i[5:0] == 0 & p_strb_i[0];
    assign req_ack_request = valid_req & rw_strobe & p_we_i & p_addr_i[5:0] == 0 & p_strb_i[1];

    /* The reset signal went to the active level (LOW) when writing 1 to the reset register */
    assign rstn_apb_w = rst_request     ? ~p_data_i[0]   :  1;

    assign req_w      = req_ack_request ?  p_data_i[1]   :  0;
    assign ack_w      = req_ack_request ?  p_data_i[0]   :  0;

endmodule