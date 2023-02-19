module kuznechik_cipher(
    input               clk_i,
                        resetn_i,
                        request_i,
                        ack_i,
                [127:0] data_i,

    output              busy_o,
           reg          valid_o,
           reg  [127:0] data_o
);

  reg [127:0] key_mem [0:9];
  reg [7:0] S_box_mem [0:255];

  reg [7:0] L_mul_16_mem  [0:255];
  reg [7:0] L_mul_32_mem  [0:255];
  reg [7:0] L_mul_133_mem [0:255];
  reg [7:0] L_mul_148_mem [0:255];
  reg [7:0] L_mul_192_mem [0:255];
  reg [7:0] L_mul_194_mem [0:255];
  reg [7:0] L_mul_251_mem [0:255];

  initial begin
      $readmemh("keys.mem",key_mem );
      $readmemh("S_box.mem",S_box_mem );

      $readmemh("L_16.mem", L_mul_16_mem );
      $readmemh("L_32.mem", L_mul_32_mem );
      $readmemh("L_133.mem",L_mul_133_mem);
      $readmemh("L_148.mem",L_mul_148_mem);
      $readmemh("L_192.mem",L_mul_192_mem);
      $readmemh("L_194.mem",L_mul_194_mem);
      $readmemh("L_251.mem",L_mul_251_mem);
  end


  logic [3:0]   trial_num_ff;
  localparam    MAX_TRIAL_NUM = 9;

  logic [127:0] trial_input_mux;

  logic [127:0] trial_output;

  assign trial_input_mux = (trial_num_ff == 0) ? data_i
                         :                       trial_output ;


  /* Key overlay */

  logic [127:0] round_key;
  assign round_key = key_mem[trial_num_ff];

  logic [127:0] data_key_result;
  assign data_key_result = trial_input_mux ^ round_key;

  /* Linear overlay */
  logic [7:0] data_key_result_bytes [15:0];
  logic [7:0] data_linear_result    [15:0];

  generate;
    for (genvar i=0; i<16; i++) begin
      assign data_key_result_bytes[i] = data_key_result[((i+1)*8)-1:(i*8)];
      assign data_linear_result   [i] = S_box_mem[data_key_result_bytes[i]];
    end
  endgenerate


  /* Galua overlay */

  logic [7:0] data_galua_in [15:0];
  logic       data_galua_sel;         // 0 - input from S_PHASE,
                                      // 1 - input from shift_reg L_PHASE

  // Stub! Shift register should be added here
  assign data_galua_in = data_galua_sel ? data_linear_result : data_galua_shreg_ff;

  logic [7:0] data_galua_result [15:0];

  // 148, 32, 133, 16, 194, 192, 1, 251, 1, 192, 194, 16, 133, 32, 148, 1
  assign data_galua_result[15]  = L_mul_148_mem [data_galua_in[15]];
  assign data_galua_result[14]  = L_mul_32_mem  [data_galua_in[14]]; 
  assign data_galua_result[13]  = L_mul_133_mem [data_galua_in[13]]; 
  assign data_galua_result[12]  = L_mul_16_mem  [data_galua_in[12]]; 
  assign data_galua_result[11]  = L_mul_194_mem [data_galua_in[11]]; 
  assign data_galua_result[10]  = L_mul_192_mem [data_galua_in[10]]; 
  assign data_galua_result[9]   =                data_galua_in[9] ;
  assign data_galua_result[8]   = L_mul_251_mem [data_galua_in[8]]; 
  assign data_galua_result[7]   =                data_galua_in[7] ;
  assign data_galua_result[6]   = L_mul_192_mem [data_galua_in[6]]; 
  assign data_galua_result[5]   = L_mul_194_mem [data_galua_in[5]]; 
  assign data_galua_result[4]   = L_mul_16_mem  [data_galua_in[4]]; 
  assign data_galua_result[3]   = L_mul_133_mem [data_galua_in[3]]; 
  assign data_galua_result[2]   = L_mul_32_mem  [data_galua_in[2]]; 
  assign data_galua_result[1]   = L_mul_148_mem [data_galua_in[1]]; 
  assign data_galua_result[0]   =                data_galua_in[0] ;

  logic [7:0] galua_summ;

  logic [7:0] data_galua_shreg_ff   [15:0];
  logic [7:0] data_galua_shreg_next [15:0];
  logic       data_galua_shreg_en;

  generate;

    always_comb begin
      galua_summ = '0;
      for (int i = 0; i < 16; i++)
        galua_summ = galua_summ ^ data_galua_result[i];
    end

    always_comb begin
      data_galua_shreg_next[15] = galua_summ;
      for (int i = 14; i >= 0; i--)
        data_galua_shreg_next[i] = data_galua_sel ? data_linear_result[i+1] : data_galua_shreg_ff[i+1];
    end

    for (genvar i = 0; i < 16; i++) begin
      always_ff @(posedge clk_i or negedge resetn_i) begin
        if (~resetn_i)
          data_galua_shreg_ff[i] <= '0;
        else if (data_galua_shreg_en)
          data_galua_shreg_ff[i] <= data_galua_shreg_next[i];
      end
    end

    for (genvar i = 0; i < 16; i++)
      assign trial_output[((i+1)*8)-1:(i*8)] = data_galua_shreg_ff[i];

  endgenerate


  /* state_ff machine logic */

  localparam IDLE      = 3'd0,
             KEY_PHASE = 3'd1,
             S_PHASE   = 3'd2,
             L_PHASE   = 3'd3,
             FINISH    = 3'd4;

  logic [2:0] state_ff;
  logic [2:0] prev_state_ff;

  logic [3:0] l_phase_counter_ff;

  assign data_galua_shreg_en = state_ff == L_PHASE;
  assign data_galua_sel = state_ff == L_PHASE && l_phase_counter_ff == '0;

  // l_phase_counter
  always_ff @(posedge clk_i or negedge resetn_i) begin
    if (~resetn_i)
      l_phase_counter_ff <= '0;
    else if (state_ff == L_PHASE)
      l_phase_counter_ff <= l_phase_counter_ff + 1;
  end

  // state_ff
  always_ff @(posedge clk_i or negedge resetn_i) begin
    if (~resetn_i)
      state_ff = IDLE;
    else if ((state_ff == IDLE || state_ff == FINISH) && request_i)
      state_ff <= KEY_PHASE;
    else if (state_ff == FINISH && ack_i)
      state_ff <= IDLE;
    else if (state_ff == KEY_PHASE)
      state_ff <= trial_num_ff == MAX_TRIAL_NUM ? FINISH : S_PHASE;
    else if (state_ff == S_PHASE)
      state_ff <= L_PHASE;
    else if (state_ff == L_PHASE && &l_phase_counter_ff)
      state_ff <= KEY_PHASE;
  end

  // prev_state_ff
  always_ff @(posedge clk_i or negedge resetn_i) begin
    if (~resetn_i)
      prev_state_ff <= IDLE;
    else
      prev_state_ff <= state_ff;
  end

  // trial_num_ff
  always_ff @(posedge clk_i or negedge resetn_i) begin
    if (~resetn_i)
      trial_num_ff <= '0;
    else if (state_ff == FINISH)
      trial_num_ff <= '0;
    else if (state_ff == L_PHASE && &l_phase_counter_ff)
        trial_num_ff <= trial_num_ff + 4'd1;
  end  

  // data_o
  always_ff @(posedge clk_i or negedge resetn_i) begin
    if (~resetn_i)
      data_o <= '0;
    else if (state_ff == FINISH && prev_state_ff != FINISH)
      data_o <= data_key_result;
  end  

  // valid_o
  always_ff @(posedge clk_i or negedge resetn_i) begin
    if (~resetn_i)
      valid_o <= '0;
    else if (state_ff == FINISH && ack_i)
      valid_o <= '0;
    else if (state_ff == FINISH && prev_state_ff != FINISH)
      valid_o <= '1;
  end  

  assign busy_o = state_ff != IDLE && state_ff != FINISH;

endmodule
