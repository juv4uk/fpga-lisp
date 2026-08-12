`include "lisp_word.sv"

module tb_cml_e2e;

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
    integer heap_i;
    string bin_file;

    initial begin
        // One generic testbench serves both the fixed smoke test and CML's
        // fixture runner. · Один testbench для smoke і fixtures.
        // Eine Testbench fuer Smoke-Test und Fixtures.
        if (!$value$plusargs("bin_file=%s", bin_file)) begin
            bin_file = "cml_e2e.bin";
        end
        fd = $fopen(bin_file, "rb");
        if (fd == 0) begin
            $display("FAILED: could not open %s", bin_file);
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from %s", n_bytes, n_words, bin_file);

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
        $display("R15 = TAG:%0d VAL:%0d", u_mac.u_regs.regs[15][31:28], u_mac.u_regs.regs[15][27:0]);
        $display("RESULT_TAG:%0d", u_mac.u_regs.regs[15][31:28]);
        $display("RESULT_VAL:%0d", u_mac.u_regs.regs[15][27:0]);
        if (u_mac.u_ctrl.err_flag) begin
            $display("RESULT_ERROR:Type");
            $display("RESULT_ERROR_PC:%0d", u_mac.u_ctrl.err_pc);
        end
        $display("HEAP_COUNT:%0d", u_mac.u_ldu.hp);
        // Stable host-facing heap dump for canonical structured decoding.
        // Стабільний dump купи для канонічного декодування структур.
        // Stabiler Heap-Dump fuer kanonische Strukturdekodierung.
        for (heap_i = 0; heap_i < u_mac.u_ldu.hp; heap_i = heap_i + 1) begin
            $display("HEAP:%0d:%0d:%0d:%0d:%0d",
                     heap_i,
                     u_mac.u_ldu.u_heap.car_ram[heap_i][31:28],
                     u_mac.u_ldu.u_heap.car_ram[heap_i][27:0],
                     u_mac.u_ldu.u_heap.cdr_ram[heap_i][31:28],
                     u_mac.u_ldu.u_heap.cdr_ram[heap_i][27:0]);
        end

        // TEST is defined as 7 in our compiler test
        if (u_mac.u_regs.regs[15][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[15][27:0] == 28'd7) begin
            $display("CML E2E PASSED");
        end else begin
            $display("CML E2E FAILED");
        end

        $finish;
    end

    initial begin
        // UART bit time is 8680 time units and load dominates total run
        // time for any real program, not execution -- a ~200-instruction
        // binary (800+ bytes) takes ~69.6M time units just to shift in
        // over the bit-banged link, right at the old 70M watchdog. cml's
        // first real end-to-end `length` run (my-lisp -> cml -> fpga-lisp,
        // mailbox 2026-08-12) hit exactly this and was misreported as a
        // hang -- it wasn't; a local 200M-watchdog copy confirmed it
        // completes with the correct RESULT_VAL. Every other testbench in
        // this repo already uses 150M; this one, being cml's E2E harness
        // for arbitrary-sized compiled programs (potentially larger than
        // any hand-assembled bootstrap demo), gets extra headroom.
        #300_000_000;
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
