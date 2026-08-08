module bootloader (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic        rx_valid,
    input  logic [7:0]  rx_data,
    
    output logic        boot_we,
    output logic [7:0]  boot_addr,
    output logic [31:0] boot_data,
    
    output logic        boot_done
);

    typedef enum logic [1:0] {
        STATE_WAIT_LENGTH,
        STATE_READ_BYTES,
        STATE_DONE
    } state_t;
    
    state_t state, next_state;
    
    logic [7:0] prog_length;
    logic [7:0] next_prog_length;
    
    logic [7:0] word_count;
    logic [7:0] next_word_count;
    
    logic [1:0] byte_count;
    logic [1:0] next_byte_count;
    
    logic [31:0] assembled_word;
    logic [31:0] next_assembled_word;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_WAIT_LENGTH;
            prog_length <= 0;
            word_count <= 0;
            byte_count <= 0;
            assembled_word <= 0;
        end else begin
            state <= next_state;
            prog_length <= next_prog_length;
            word_count <= next_word_count;
            byte_count <= next_byte_count;
            assembled_word <= next_assembled_word;
        end
    end
    
    always_comb begin
        next_state = state;
        next_prog_length = prog_length;
        next_word_count = word_count;
        next_byte_count = byte_count;
        next_assembled_word = assembled_word;
        
        boot_we = 0;
        boot_addr = word_count;
        boot_data = assembled_word;
        boot_done = 0;
        
        case (state)
            STATE_WAIT_LENGTH: begin
                if (rx_valid) begin
                    next_prog_length = rx_data;
                    if (rx_data == 0) begin
                        next_state = STATE_DONE;
                    end else begin
                        next_state = STATE_READ_BYTES;
                        next_word_count = 0;
                        next_byte_count = 0;
                        next_assembled_word = 0;
                    end
                end
            end
            
            STATE_READ_BYTES: begin
                if (rx_valid) begin
                    // Assemble word (Little Endian)
                    case (byte_count)
                        2'd0: next_assembled_word[7:0]   = rx_data;
                        2'd1: next_assembled_word[15:8]  = rx_data;
                        2'd2: next_assembled_word[23:16] = rx_data;
                        2'd3: next_assembled_word[31:24] = rx_data;
                    endcase
                    
                    if (byte_count == 2'd3) begin
                        boot_we = 1;
                        boot_data = next_assembled_word; // Use the fully assembled word
                        
                        next_word_count = word_count + 1;
                        next_byte_count = 0;
                        
                        if (word_count + 1 == prog_length) begin
                            next_state = STATE_DONE;
                        end
                    end else begin
                        next_byte_count = byte_count + 1;
                    end
                end
            end
            
            STATE_DONE: begin
                boot_done = 1;
            end
        endcase
    end

endmodule
