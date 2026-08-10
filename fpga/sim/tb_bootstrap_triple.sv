`include "lisp_word.sv"

// M24: a genuine three-parameter closure -- proves the N-ary
// generalization in eval_core.inc's closure_nary loop works beyond
// N=2 (M22's pair only ever exercised two parameters).
// (lambda (a b c) (cons a (cons b c))) applied to ('x 'y 'z)
// => (x y . z): outer.car='x, outer.cdr=inner; inner.car='y, inner.cdr='z.
module tb_bootstrap_triple;

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
    integer outer_addr, inner_addr;
    lisp_word_t outer_car, outer_cdr, inner_car, inner_cdr;

    initial begin
        $dumpfile("tb_bootstrap_triple.vcd");
        $dumpvars(0, tb_bootstrap_triple);

        fd = $fopen("bootstrap_triple_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_triple_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_triple_demo.bin", n_bytes, n_words);

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
        $display("R9 (triple 'x 'y 'z) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[9][31:28] == TAG_CONS) begin
            outer_addr = u_mac.u_regs.regs[9][27:0];
            outer_car = u_mac.u_ldu.u_heap.car_ram[outer_addr];
            outer_cdr = u_mac.u_ldu.u_heap.cdr_ram[outer_addr];
            $display("  outer[%0d] = (TAG:%0d VAL:%0d . TAG:%0d VAL:%0d)",
                outer_addr, outer_car.tag, outer_car.value, outer_cdr.tag, outer_cdr.value);
            if (outer_car.tag == TAG_SYMBOL && outer_car.value == 28'd2030 &&
                outer_cdr.tag == TAG_CONS) begin
                inner_addr = outer_cdr.value;
                inner_car = u_mac.u_ldu.u_heap.car_ram[inner_addr];
                inner_cdr = u_mac.u_ldu.u_heap.cdr_ram[inner_addr];
                $display("  inner[%0d] = (TAG:%0d VAL:%0d . TAG:%0d VAL:%0d)",
                    inner_addr, inner_car.tag, inner_car.value, inner_cdr.tag, inner_cdr.value);
                if (inner_car.tag == TAG_SYMBOL && inner_car.value == 28'd2031 &&
                    inner_cdr.tag == TAG_SYMBOL && inner_cdr.value == 28'd2032) begin
                    $display("M24 PASSED: three-parameter closure works");
                end else begin
                    $display("M24 FAILED: wrong inner car/cdr");
                end
            end else begin
                $display("M24 FAILED: wrong outer car/cdr");
            end
        end else begin
            $display("M24 FAILED: result is not a CONS");
        end

        $finish;
    end

    initial begin
        #120_000_000; // watchdog
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
