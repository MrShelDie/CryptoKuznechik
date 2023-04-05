module kuznechik_cipher_wrapper(
    input               p_clk_i,
    input               p_rstn_i,
    input       [31:0]  p_dat_i,
    output  reg [31:0]  p_dat_o,
    input               p_sel_i,
    input               p_enable_i,
    input               p_we_i,
    input       [31:0]  p_adr_i,
    output  reg         p_ready_o
);


    /* To kuznechik_cipher */
    logic   [127:0] data_out_r;   // Data from kuznechik_cipher
    logic           busy_r;
    logic           valid_r;

    logic   [127:0] data_in_w;    // Data to kuznechik_cipher
    logic           request_w;    // kuznechik_cipher activation signal
    logic           rstn_apb_w;   // System bus reset signal

    logic           rstn = p_rstn_i & rstn_apb_w;

    kuznechik_cipher kuznechik_cipher(
        .clk_i      ( p_clk_i  ),
        .resetn_i   ( rstn     ),
        .request_i  ( request  ),
        .ack_i      ( request  ),
        .data_i     ( data_in  ),

        .busy_o     ( busy     ),
        .valid_o    ( valid    ),
        .data_o     ( data_out ),
    );


    /* Generating a read/write strobe on the system bus */
    logic rw_strobe_1_ff;
    logic rw_strobe_2_ff;
    logic rw_strobe = rw_strobe_1_ff & ~rw_strobe_2_ff;

    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i) begin
            rw_strobe_1_ff <= '0;
            rw_strobe_2_ff <= '0;
        end
        else begin
            rw_strobe_1_ff <= p_enable_i & p_sel_i;
            rw_strobe_2_ff <= rw_strobe_1_ff;
        end
    end


    /* Generation of system bus ready signal p_ready */
    logic ready_1_ff;
    logic ready_2_ff;

    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i) begin
            ready_1_ff <= '0;
            ready_2_ff <= '0;
        end
        else begin
            ready_1_ff <= rw_strobe_2_ff;
            ready_2_ff <= ready_1_ff;
        end
    end

    always_ff @(posedge p_clk_i or negedge p_rstn_i) begin
        if (~p_rstn_i)
            p_ready_o <= '0;
        else
            p_ready_o <= ready_1_ff & ~ready_2_ff;
    end


endmodule