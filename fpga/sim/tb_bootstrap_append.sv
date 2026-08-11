`include "lisp_word.sv"

// M31: canonical core.my `append`, built on top of the M30 reverse-onto/
// reverse letrec pair: (lambda (left right) (reverse-onto (reverse left)
// right)). Not self-referential -- see bootstrap_append_demo.asm's header
// for why no third letrec placeholder is needed.
// (append '(a b) '(c d)) => (a b c d) -- a 4-element CONS structure, so
// this testbench walks car_ram/cdr_ram directly (same pattern as
// tb_bootstrap_reverse.sv) instead of reading a single register.
module tb_bootstrap_append;

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

    lisp_word_t r9;
    integer addr1, addr2, addr3, addr4;
    lisp_word_t car1, cdr1, car2, cdr2, car3, cdr3, car4, cdr4;

    initial begin
        fd = $fopen("bootstrap_append_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_append_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_append_demo.bin", n_bytes, n_words);

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
        r9 = u_mac.u_regs.regs[9];
        $display("R9 (append '(a b) '(c d)) = TAG:%0d VAL:%0d", r9.tag, r9.value);

        if (r9.tag != TAG_CONS) begin
            $display("M31 FAILED: R9 is not a CONS (expected a 4-element list)");
            $finish;
        end

        addr1 = r9.value;
        car1 = u_mac.u_ldu.u_heap.car_ram[addr1];
        cdr1 = u_mac.u_ldu.u_heap.cdr_ram[addr1];
        $display("cell1[%0d]: car=TAG:%0d VAL:%0d cdr=TAG:%0d VAL:%0d", addr1, car1.tag, car1.value, cdr1.tag, cdr1.value);

        if (!(car1.tag == TAG_SYMBOL && car1.value == 28'd930 && cdr1.tag == TAG_CONS)) begin
            $display("M31 FAILED: first element isn't 'a (930) or tail isn't a CONS");
            $finish;
        end

        addr2 = cdr1.value;
        car2 = u_mac.u_ldu.u_heap.car_ram[addr2];
        cdr2 = u_mac.u_ldu.u_heap.cdr_ram[addr2];
        $display("cell2[%0d]: car=TAG:%0d VAL:%0d cdr=TAG:%0d VAL:%0d", addr2, car2.tag, car2.value, cdr2.tag, cdr2.value);

        if (!(car2.tag == TAG_SYMBOL && car2.value == 28'd931 && cdr2.tag == TAG_CONS)) begin
            $display("M31 FAILED: second element isn't 'b (931) or tail isn't a CONS");
            $finish;
        end

        addr3 = cdr2.value;
        car3 = u_mac.u_ldu.u_heap.car_ram[addr3];
        cdr3 = u_mac.u_ldu.u_heap.cdr_ram[addr3];
        $display("cell3[%0d]: car=TAG:%0d VAL:%0d cdr=TAG:%0d VAL:%0d", addr3, car3.tag, car3.value, cdr3.tag, cdr3.value);

        if (!(car3.tag == TAG_SYMBOL && car3.value == 28'd932 && cdr3.tag == TAG_CONS)) begin
            $display("M31 FAILED: third element isn't 'c (932) or tail isn't a CONS");
            $finish;
        end

        addr4 = cdr3.value;
        car4 = u_mac.u_ldu.u_heap.car_ram[addr4];
        cdr4 = u_mac.u_ldu.u_heap.cdr_ram[addr4];
        $display("cell4[%0d]: car=TAG:%0d VAL:%0d cdr=TAG:%0d VAL:%0d", addr4, car4.tag, car4.value, cdr4.tag, cdr4.value);

        if (car4.tag == TAG_SYMBOL && car4.value == 28'd933 && cdr4.tag == TAG_NIL) begin
            $display("M31 PASSED: append via reverse/reverse-onto works, (append '(a b) '(c d)) => (a b c d)");
        end else begin
            $display("M31 FAILED: fourth element isn't 'd (933) or tail isn't NIL");
        end

        $finish;
    end

    initial begin
        #150_000_000;
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
