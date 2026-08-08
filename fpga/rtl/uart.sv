module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] tx_data,
    input  logic tx_start,
    output logic tx,
    output logic tx_busy
);
    localparam int CLK_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state, next_state;
    
    logic [$clog2(CLK_PER_BIT)-1:0] clk_cnt;
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            tx <= 1;
            tx_busy <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1;
                    tx_busy <= 0;
                    if (tx_start) begin
                        state <= START;
                        shift_reg <= tx_data;
                        clk_cnt <= 0;
                        tx_busy <= 1;
                    end
                end
                
                START: begin
                    tx <= 0;
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        state <= DATA;
                        clk_cnt <= 0;
                        bit_cnt <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                
                DATA: begin
                    tx <= shift_reg[0];
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        shift_reg <= shift_reg >> 1;
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                
                STOP: begin
                    tx <= 1;
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        state <= IDLE;
                        clk_cnt <= 0;
                        tx_busy <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic clk,
    input  logic rst_n,
    input  logic rx,
    output logic [7:0] rx_data,
    output logic rx_valid
);
    localparam int CLK_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;
    
    logic [$clog2(CLK_PER_BIT)-1:0] clk_cnt;
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;
    logic rx_d1, rx_d2;
    
    // Double flop for metastability
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_d1 <= 1;
            rx_d2 <= 1;
        end else begin
            rx_d1 <= rx;
            rx_d2 <= rx_d1;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_cnt <= 0;
            rx_data <= 0;
            rx_valid <= 0;
            shift_reg <= 0;
        end else begin
            rx_valid <= 0; // Default pulse
            
            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    if (rx_d2 == 0) begin // Start bit detected
                        state <= START;
                    end
                end
                
                START: begin
                    if (clk_cnt == (CLK_PER_BIT / 2)) begin
                        if (rx_d2 == 0) begin
                            clk_cnt <= 0;
                            state <= DATA;
                            bit_cnt <= 0;
                        end else begin
                            state <= IDLE; // False start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                
                DATA: begin
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        shift_reg <= {rx_d2, shift_reg[7:1]};
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                
                STOP: begin
                    if (clk_cnt == CLK_PER_BIT - 1) begin
                        state <= IDLE;
                        if (rx_d2 == 1) begin
                            rx_data <= shift_reg;
                            rx_valid <= 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule
