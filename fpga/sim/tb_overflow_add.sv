`include "lisp_word.sv"

// evidence/ISA-RATIONAL/limb-base-fixture.md gate G4: "28-bit payload
// overflow -> named failure OR multi-limb transition; never a silent
// wrap." Characterizes what the CURRENT hardware ADD (a plain
// TAG_FIXNUM primitive, unrelated to the not-yet-built TAG_BIGNUM)
// actually does when a sum exceeds the 28-bit payload's maximum
// representable value, so a G4 overflow-detection design can be
// proposed against a verified fact instead of an assumption.
// overflow_add_demo.asm builds 2^27 by repeated doubling, then adds it
// to itself: 2^27 + 2^27 = 2^28, exactly one past 28'd268435455 (the
// maximum TAG_FIXNUM payload value).
module tb_overflow_add;

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
    byte prog_bytes[0:2047];
    integer n_words;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_overflow_add.vcd");
            $dumpvars(0, tb_overflow_add);
        end

        fd = $fopen("overflow_add_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open overflow_add_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from overflow_add_demo.bin", n_bytes, n_words);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(n_words[7:0]);
        send_uart_byte(n_words[15:8]);
        for (int i = 0; i < n_bytes; i = i + 1) begin
            send_uart_byte(prog_bytes[i]);
        end

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R1 (2^27) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[1][31:28], u_mac.u_regs.regs[1][27:0]);
        $display("R2 (2^27 + 2^27, should be 2^28 if not truncated) = TAG:%0d VAL:%0d",
                  u_mac.u_regs.regs[2][31:28], u_mac.u_regs.regs[2][27:0]);

        if (u_mac.u_regs.regs[1][27:0] !== 28'd134217728) begin
            $display("FAILED: R1 (2^27 via doubling) did not compute correctly -- test setup is wrong, not evidence about overflow");
        end else if (u_mac.u_regs.regs[2][27:0] == 28'd0) begin
            $display("G4 EVIDENCE: CONFIRMED SILENT WRAP -- hardware ADD truncates 2^27+2^27 (=2^28) to 0 mod 2^28, no error flag, no distinguishable failure signal. G4's overflow-detection mechanism must live OUTSIDE this instruction (e.g. a host/microcode-side bounds check on the operands before emitting ADD), since the instruction itself cannot self-report an out-of-range sum with the current RTL.");
        end else begin
            $display("G4 EVIDENCE: sum was NOT silently wrapped to 0 (got %0d) -- does not match the silent-wrap hypothesis, needs its own investigation before drawing a G4 conclusion.", u_mac.u_regs.regs[2][27:0]);
        end

        $finish;
    end

    initial begin
        #120_000_000;
        $display("WATCHDOG TIMEOUT: test hung");
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
