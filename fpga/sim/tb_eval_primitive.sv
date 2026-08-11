`include "lisp_word.sv"

// M16 eval-primitive-apply: bind 'car and 'cons in a base environment
// to PRIMITIVE-tagged markers (new TAG_PRIMITIVE, made via the MOV
// submode MAKEPRIM) instead of closures, and teach eval's application
// path to dispatch straight to the hardware CAR/CONS opcodes when the
// evaluated operator is a primitive. Reaches the plan's literal
// Etap-1 goal: (eval '(car (cons 'a 'b)) env) => a.
//
// The program is large (186 instructions) and assembled externally by
// assembler.py, so this testbench reads eval_primitive_demo.bin
// directly via $fread instead of hand-transcribing hex words.
module tb_eval_primitive;

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

    integer fd;
    integer n_bytes;
    byte prog_bytes[0:1023];
    integer n_words;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_eval_primitive.vcd");
            $dumpvars(0, tb_eval_primitive);
        end

        fd = $fopen("eval_primitive_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open eval_primitive_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from eval_primitive_demo.bin", n_bytes, n_words);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(n_words[7:0]);
        send_uart_byte(n_words[15:8]); // program length hi byte
        for (int i = 0; i < n_bytes; i = i + 1) begin
            send_uart_byte(prog_bytes[i]);
        end

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R9 (eval (car (cons 'a 'b))) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[9][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[9][27:0] == 28'd210) begin
            $display("M16 PASSED: eval-primitive-apply reaches (eval '(car (cons 'a 'b)) env) => a");
        end else begin
            $display("M16 FAILED");
        end

        $finish;
    end

    initial begin
        #70_000_000; // watchdog (186-instruction upload alone takes ~65ms)
        $display("WATCHDOG TIMEOUT: test hung");
        $display("[dbg] pc=%0d state=%0d R3=%h R4=%h R5=%h R6=%h R7=%h R8=%h R9=%h R10=%h R11=%h",
            u_mac.u_ctrl.pc, u_mac.u_ctrl.state,
            u_mac.u_regs.regs[3], u_mac.u_regs.regs[4], u_mac.u_regs.regs[5],
            u_mac.u_regs.regs[6], u_mac.u_regs.regs[7], u_mac.u_regs.regs[8],
            u_mac.u_regs.regs[9], u_mac.u_regs.regs[10], u_mac.u_regs.regs[11]);
        $finish;
    end

    task send_uart_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 0; // Start bit
            #(8680);
            for (i=0; i<8; i=i+1) begin
                uart_rx = b[i];
                #(8680);
            end
            uart_rx = 1; // Stop bit
            #(8680);
        end
    endtask

endmodule
