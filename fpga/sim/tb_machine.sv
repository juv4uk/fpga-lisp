`include "lisp_word.sv"

module tb_machine;

    logic clk;
    logic rst_n;
    logic halted;
    logic uart_tx;
    logic uart_rx;
    
    lisp_machine u_mac (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted),
        .uart_rx_in(uart_rx),
        .uart_tx_out(uart_tx)
    );
    
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    initial begin
        $dumpfile("tb_machine.vcd");
        $dumpvars(0, tb_machine);
        
        uart_rx = 1; // Default to IDLE state
        rst_n = 0;
        #20 rst_n = 1;
        
        // Wait for reset to finish
        #100;
        
        // We will send 5 instructions (length = 5)
        send_uart_byte(8'd5);
        send_uart_byte(8'd0); // program length hi byte
        
        // 0: LOADSYM R1, SYMBOL A (id=2) -> 32'h91000002
        send_uart_word(32'h91000002);

        // 1: LOADSYM R2, SYMBOL B (id=3) -> 32'h92000003
        send_uart_word(32'h92000003);
        
        // 2: CONS R3, R1, R2 -> 32'h33120000
        send_uart_word(32'h33120000);
        
        // 3: CAR R4, R3 -> 32'h44300000
        send_uart_word(32'h44300000);
        
        // 4: HALT -> 32'hB0000000
        send_uart_word(32'hB0000000);
        
        // Wait until halted
        wait(halted);
        #50;
        
        $display("Machine Halted.");
        $display("R1 = TAG:%0d VAL:%0d", u_mac.u_regs.regs[1][31:28], u_mac.u_regs.regs[1][27:0]);
        $display("R2 = TAG:%0d VAL:%0d", u_mac.u_regs.regs[2][31:28], u_mac.u_regs.regs[2][27:0]);
        $display("R3 = TAG:%0d VAL:%0d", u_mac.u_regs.regs[3][31:28], u_mac.u_regs.regs[3][27:0]);
        $display("R4 = TAG:%0d VAL:%0d", u_mac.u_regs.regs[4][31:28], u_mac.u_regs.regs[4][27:0]);
        
        if (u_mac.u_regs.regs[4][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[4][27:0] == 28'd2) begin
            $display("MILESTONE 0.03 PASSED: Bootloader executed (car (cons 'a 'b))!");
        end else begin
            $display("FAILED");
        end
        
        $finish;
    end
    
    task send_uart_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 0; // Start bit
            #(8680); // 1 / 115200 * 1e9 ns = 8680.5 ns
            for (i=0; i<8; i=i+1) begin
                uart_rx = b[i];
                #(8680);
            end
            uart_rx = 1; // Stop bit
            #(8680);
        end
    endtask
    
    task send_uart_word(input [31:0] w);
        begin
            send_uart_byte(w[7:0]);
            send_uart_byte(w[15:8]);
            send_uart_byte(w[23:16]);
            send_uart_byte(w[31:24]);
        end
    endtask

endmodule
