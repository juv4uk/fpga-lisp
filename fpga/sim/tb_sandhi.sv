// ============================================================================
// tb_sandhi.sv — Unit test for sandhi_engine (Step C embryo, 3 rules)
// ============================================================================
// 16 golden cases covering all three rules + passthrough.
// Run: iverilog -g2012 -o tb_sandhi.vvp fpga/rtl/sandhi_engine.sv fpga/sim/tb_sandhi.sv
//       vvp tb_sandhi.vvp
// ============================================================================

`timescale 1ns/1ps

module tb_sandhi;

    logic clk = 0;
    logic rst_n = 0;
    logic start;
    logic [7:0] code_prev;
    logic [7:0] code_curr;
    logic done;
    logic [1:0] result_mode;
    logic [7:0] result_0;
    logic [7:0] result_1;

    integer failures = 0;

    sandhi_engine dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .code_prev(code_prev),
        .code_curr(code_curr),
        .done(done),
        .result_mode(result_mode),
        .result_0(result_0),
        .result_1(result_1),
        .error()
    );

    always #5 clk = ~clk;

    // {prev, curr} golden cases
    // prev / curr / rule / mode / out0 / out1
    logic [7:0] g_prev [0:15];
    logic [7:0] g_curr [0:15];
    string     g_label [0:15];
    logic [1:0] g_mode [0:15];
    logic [7:0] g_out0 [0:15];
    logic [7:0] g_out1 [0:15];
    integer    g_latency [0:15];   // expected cycles start->done

    initial begin
        // GUNA (rule 1)
        g_prev[0]=8'h80; g_curr[0]=8'h88; g_label[0]="GUNA a+i  -> e";    g_mode[0]=2'b01; g_out0[0]=8'hA8; g_out1[0]=8'h00; g_latency[0]=7;
        g_prev[1]=8'h80; g_curr[1]=8'h89; g_label[1]="GUNA a+ii -> e";    g_mode[1]=2'b01; g_out0[1]=8'hA8; g_out1[1]=8'h00; g_latency[1]=7;
        g_prev[2]=8'h80; g_curr[2]=8'h90; g_label[2]="GUNA a+u  -> o";    g_mode[2]=2'b01; g_out0[2]=8'hB0; g_out1[2]=8'h00; g_latency[2]=7;
        g_prev[3]=8'h80; g_curr[3]=8'h91; g_label[3]="GUNA a+uu -> o";    g_mode[3]=2'b01; g_out0[3]=8'hB0; g_out1[3]=8'h00; g_latency[3]=7;
        // SAVARNA-DĪRGHA (rule 0)
        g_prev[4]=8'h80; g_curr[4]=8'h81; g_label[4]="SAV a+aa  -> aa";   g_mode[4]=2'b01; g_out0[4]=8'h81; g_out1[4]=8'h00; g_latency[4]=4;
        g_prev[5]=8'h81; g_curr[5]=8'h80; g_label[5]="SAV aa+a  -> aa";   g_mode[5]=2'b01; g_out0[5]=8'h81; g_out1[5]=8'h00; g_latency[5]=4;
        g_prev[6]=8'h88; g_curr[6]=8'h89; g_label[6]="SAV i+ii  -> ii";   g_mode[6]=2'b01; g_out0[6]=8'h89; g_out1[6]=8'h00; g_latency[6]=4;
        g_prev[7]=8'h88; g_curr[7]=8'h88; g_label[7]="SAV i+i   -> ii";   g_mode[7]=2'b01; g_out0[7]=8'h89; g_out1[7]=8'h00; g_latency[7]=4;
        g_prev[8]=8'h90; g_curr[8]=8'h91; g_label[8]="SAV u+uu  -> uu";   g_mode[8]=2'b01; g_out0[8]=8'h91; g_out1[8]=8'h00; g_latency[8]=4;
        g_prev[9]=8'h90; g_curr[9]=8'h90; g_label[9]="SAV u+u   -> uu";   g_mode[9]=2'b01; g_out0[9]=8'h91; g_out1[9]=8'h00; g_latency[9]=4;
        // YAṆ (rule 2)
        g_prev[10]=8'h88; g_curr[10]=8'h80; g_label[10]="YAN i+a   -> y+a"; g_mode[10]=2'b10; g_out0[10]=8'h0A; g_out1[10]=8'h80; g_latency[10]=10;
        g_prev[11]=8'h88; g_curr[11]=8'h90; g_label[11]="YAN i+u   -> y+u"; g_mode[11]=2'b10; g_out0[11]=8'h0A; g_out1[11]=8'h90; g_latency[11]=10;
        g_prev[12]=8'h90; g_curr[12]=8'h80; g_label[12]="YAN u+a   -> v+a"; g_mode[12]=2'b10; g_out0[12]=8'h0B; g_out1[12]=8'h80; g_latency[12]=10;
        g_prev[13]=8'h90; g_curr[13]=8'h88; g_label[13]="YAN u+i   -> v+i"; g_mode[13]=2'b10; g_out0[13]=8'h0B; g_out1[13]=8'h88; g_latency[13]=10;
        g_prev[14]=8'h88; g_curr[14]=8'h81; g_label[14]="YAN i+aa  -> y+aa";g_mode[14]=2'b10; g_out0[14]=8'h0A; g_out1[14]=8'h81; g_latency[14]=10;
        // Passthrough (no rule)
        g_prev[15]=8'h23; g_curr[15]=8'h80; g_label[15]="NONE k+a  -> k+a"; g_mode[15]=2'b00; g_out0[15]=8'h23; g_out1[15]=8'h80; g_latency[15]=10;

        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);
        start = 0;

        for (integer c = 0; c < 16; c = c + 1) begin
            run_case(c);
        end

        if (failures == 0) begin
            $display("=== tb_sandhi: ALL 16 CASES PASS ===");
            $finish;
        end else begin
            $display("=== tb_sandhi: %0d FAILURES ===", failures);
            $finish(2);
        end
    end

    task run_case(input integer c);
        integer cycles;
        begin
            code_prev = g_prev[c];
            code_curr = g_curr[c];
            @(negedge clk);
            start = 1;
            @(negedge clk);
            start = 0;
            cycles = 0;
            while (!done) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            // sample while done is high
            #1;
            if (result_mode !== g_mode[c] ||
                result_0     !== g_out0[c] ||
                result_1     !== g_out1[c]) begin
                $display("FAIL [%0d] %0s: prev=%02X curr=%02X mode=%b out0=%02X out1=%02X (exp mode=%b out0=%02X out1=%02X)",
                    c, g_label[c], code_prev, code_curr,
                    result_mode, result_0, result_1, g_mode[c], g_out0[c], g_out1[c]);
                failures = failures + 1;
            end else begin
                $display("ok   [%0d] %0s -> mode=%b out0=%02X out1=%02X (latency=%0d)",
                    c, g_label[c], result_mode, result_0, result_1, cycles);
            end
            @(negedge clk); // let engine return to IDLE
        end
    endtask

endmodule