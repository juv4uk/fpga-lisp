module selector_path_dynamic #(
    parameter int MAX_DEPTH = 64
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic root_is_cdr,
    input  logic [MAX_DEPTH-1:0] suffix_outer_to_inner,
    input  logic [$clog2(MAX_DEPTH+1)-1:0] depth,
    output logic op_valid,
    output logic op_is_cdr,
    output logic done
);
    logic [MAX_DEPTH-1:0] suffix_q;
    logic root_q;
    logic [$clog2(MAX_DEPTH+1)-1:0] depth_q;
    logic [$clog2(MAX_DEPTH+2)-1:0] step_q;
    logic active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            suffix_q <= '0;
            root_q <= 1'b0;
            depth_q <= '0;
            step_q <= '0;
            active <= 1'b0;
            op_valid <= 1'b0;
            op_is_cdr <= 1'b0;
            done <= 1'b0;
        end else begin
            op_valid <= 1'b0;
            done <= 1'b0;
            if (start && !active) begin
                suffix_q <= suffix_outer_to_inner;
                root_q <= root_is_cdr;
                depth_q <= depth;
                step_q <= '0;
                active <= 1'b1;
            end else if (active) begin
                op_valid <= 1'b1;
                if (step_q < depth_q) begin
                    op_is_cdr <= suffix_q[depth_q - 1'b1 - step_q];
                    step_q <= step_q + 1'b1;
                end else begin
                    op_is_cdr <= root_q;
                    active <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule

module selector_path_static #(
    parameter int DEPTH = 8,
    parameter bit ROOT_IS_CDR = 1'b0,
    parameter logic [DEPTH-1:0] SUFFIX_OUTER_TO_INNER = '0
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic op_valid,
    output logic op_is_cdr,
    output logic done
);
    localparam int CW = (DEPTH + 2 <= 2) ? 1 : $clog2(DEPTH + 2);
    logic [CW-1:0] step_q;
    logic active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_q <= '0;
            active <= 1'b0;
            op_valid <= 1'b0;
            op_is_cdr <= 1'b0;
            done <= 1'b0;
        end else begin
            op_valid <= 1'b0;
            done <= 1'b0;
            if (start && !active) begin
                step_q <= '0;
                active <= 1'b1;
            end else if (active) begin
                op_valid <= 1'b1;
                if (step_q < DEPTH) begin
                    op_is_cdr <= SUFFIX_OUTER_TO_INNER[DEPTH - 1 - step_q];
                    step_q <= step_q + 1'b1;
                end else begin
                    op_is_cdr <= ROOT_IS_CDR;
                    active <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule
