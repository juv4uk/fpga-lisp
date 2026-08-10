`include "lisp_word.sv"

module lisp_machine (
    input  logic clk,
    input  logic rst_n,
    output logic halted,
    input  logic uart_rx_in,
    output logic uart_tx_out
);


    // Submodules
    logic [3:0]   reg_rd_addr_a;
    logic [3:0]   reg_rd_addr_b;
    lisp_word_t   reg_rd_data_a;
    lisp_word_t   reg_rd_data_b;
    logic         reg_we;
    logic [3:0]   reg_wr_addr;
    lisp_word_t   reg_wr_data;
    logic [11:0]  pc;
    logic [31:0]  instr;

    // CPU Reset Control
    logic boot_done;
    logic cpu_rst_n;
    assign cpu_rst_n = rst_n & boot_done;

    // Bootloader FSM
    logic boot_we;
    logic [11:0] boot_addr;
    logic [31:0] boot_data;

    logic [7:0] uart_rx_data;
    logic uart_rx_valid;

    bootloader #(
        .ADDR_WIDTH(12)
    ) u_boot (
        .clk(clk),
        .rst_n(rst_n),
        .rx_valid(uart_rx_valid),
        .rx_data(uart_rx_data),
        .boot_we(boot_we),
        .boot_addr(boot_addr),
        .boot_data(boot_data),
        .boot_done(boot_done)
    );

    // Instruction Memory (IMEM) - 4096 words (12-bit PC)
    logic [31:0] imem [0:4095];
    always_ff @(posedge clk) begin
        if (boot_we) begin
            imem[boot_addr] <= boot_data;
        end
    end

    // Asynchronous read for control unit
    assign instr = imem[pc];
    
    registers u_regs (
        .clk(clk),
        .rst_n(cpu_rst_n),
        .rd_addr_a(reg_rd_addr_a),
        .rd_addr_b(reg_rd_addr_b),
        .rd_data_a(reg_rd_data_a),
        .rd_data_b(reg_rd_data_b),
        .we(reg_we),
        .wr_addr(reg_wr_addr),
        .wr_data(reg_wr_data)
    );
    
    // --- Lisp Data Unit (Heap + Primitives) ---
    logic ldu_cmd_cons, ldu_cmd_car, ldu_cmd_cdr, ldu_cmd_setcdr;
    lisp_word_t ldu_result;
    logic ldu_valid, ldu_error;

    // Debug/monitor raw heap access (active only after HALT)
    logic mon_peek_cmd;
    logic [11:0] mon_peek_addr;
    lisp_word_t mon_peek_car, mon_peek_cdr;
    logic mon_peek_valid;
    logic [11:0] ldu_hp;

    lisp_data_unit u_ldu (
        .clk(clk),
        .rst_n(cpu_rst_n), // Use CPU reset

        .cmd_cons(ldu_cmd_cons),
        .cmd_car(ldu_cmd_car),
        .cmd_cdr(ldu_cmd_cdr),
        .cmd_setcdr(ldu_cmd_setcdr),

        .op_a(reg_rd_data_a),
        .op_b(reg_rd_data_b),

        .result(ldu_result),
        .valid(ldu_valid),
        .error(ldu_error),

        .cmd_peek(mon_peek_cmd),
        .peek_addr(mon_peek_addr),
        .peek_car(mon_peek_car),
        .peek_cdr(mon_peek_cdr),
        .peek_valid(mon_peek_valid),

        .hp_out(ldu_hp)
    );
    
    // --- UART Modules ---
    logic uart_tx_start;
    logic [7:0] uart_tx_data;
    logic uart_tx_busy;
    
    // 1-byte holding buffer for UART RX
    logic [7:0] in_data;
    logic in_valid;
    logic in_ack;
    
    always_ff @(posedge clk or negedge cpu_rst_n) begin
        if (!cpu_rst_n) begin
            in_valid <= 0;
            in_data <= 0;
        end else begin
            if (uart_rx_valid) begin
                in_valid <= 1;
                in_data <= uart_rx_data;
            end else if (in_ack) begin
                in_valid <= 0;
            end
        end
    end
    
    // --- Control Unit ---
    control u_ctrl (
        .clk(clk),
        .rst_n(cpu_rst_n), // Use CPU reset
        
        .imem_addr(pc),
        .imem_data(instr),
        
        .reg_rd_addr_a(reg_rd_addr_a),
        .reg_rd_addr_b(reg_rd_addr_b),
        .reg_rd_data_a(reg_rd_data_a),
        .reg_rd_data_b(reg_rd_data_b),
        .reg_we(reg_we),
        .reg_wr_addr(reg_wr_addr),
        .reg_wr_data(reg_wr_data),
        
        .ldu_cmd_cons(ldu_cmd_cons),
        .ldu_cmd_car(ldu_cmd_car),
        .ldu_cmd_cdr(ldu_cmd_cdr),
        .ldu_cmd_setcdr(ldu_cmd_setcdr),
        .ldu_result(ldu_result),
        .ldu_valid(ldu_valid),
        .ldu_error(ldu_error),
        
        .out_data(uart_tx_data),
        .out_valid(uart_tx_start),
        .out_busy(uart_tx_busy),
        
        .in_data(in_data),
        .in_valid(in_valid),
        .in_ack(in_ack),

        .mon_peek_cmd(mon_peek_cmd),
        .mon_peek_addr(mon_peek_addr),
        .mon_peek_car(mon_peek_car),
        .mon_peek_cdr(mon_peek_cdr),
        .mon_peek_valid(mon_peek_valid),
        .hp_in({4'd0, ldu_hp}),

        .halted(halted)
    );
    
    // --- UART Modules ---
    
    uart_tx u_uart_tx (
        .clk(clk),
        .rst_n(rst_n), // Keep running during boot
        .tx_start(uart_tx_start),
        .tx_data(uart_tx_data),
        .tx(uart_tx_out),
        .tx_busy(uart_tx_busy)
    );

    uart_rx u_uart_rx (
        .clk(clk),
        .rst_n(rst_n), // Keep running during boot
        .rx(uart_rx_in),
        .rx_data(uart_rx_data),
        .rx_valid(uart_rx_valid)
    );

endmodule
