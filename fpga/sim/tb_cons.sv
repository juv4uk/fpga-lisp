`include "lisp_word.sv"

module tb_cons;

    logic clk;
    logic rst_n;
    
    logic cmd_cons;
    logic cmd_car;
    logic cmd_cdr;
    
    lisp_word_t op_a;
    lisp_word_t op_b;
    
    lisp_word_t result;
    logic valid;
    logic error;
    
    lisp_data_unit u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_cons(cmd_cons),
        .cmd_car(cmd_car),
        .cmd_cdr(cmd_cdr),
        .op_a(op_a),
        .op_b(op_b),
        .result(result),
        .valid(valid),
        .error(error)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        $dumpfile("tb_cons.vcd");
        $dumpvars(0, tb_cons);
        
        rst_n = 0;
        cmd_cons = 0;
        cmd_car = 0;
        cmd_cdr = 0;
        op_a = '0;
        op_b = '0;
        
        #20 rst_n = 1;
        
        // Let's do: (cons 'a 'b)
        // Assume 'a is SYMBOL #2, 'b is SYMBOL #3
        #10;
        op_a.tag = TAG_SYMBOL;
        op_a.value = 28'd2; // A
        op_b.tag = TAG_SYMBOL;
        op_b.value = 28'd3; // B
        cmd_cons = 1;
        
        #10;
        cmd_cons = 0;
        
        // Wait for valid result
        wait(valid);
        #10;
        
        $display("CONS Result: TAG=%0d, VALUE=%0d", result.tag, result.value);
        
        // Now do (car <cons-result>)
        op_a = result;
        cmd_car = 1;
        
        #10;
        cmd_car = 0;
        
        wait(valid);
        #10;
        
        $display("CAR Result: TAG=%0d, VALUE=%0d", result.tag, result.value);
        if (result.tag == TAG_SYMBOL && result.value == 28'd2) begin
            $display("TEST PASSED: (car (cons 'a 'b)) == a");
        end else begin
            $display("TEST FAILED!");
        end
        
        #50 $finish;
    end

endmodule
