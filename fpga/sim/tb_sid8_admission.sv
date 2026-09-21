module tb_sid8_admission;
  logic [7:0] sid;
  logic admitted;
  logic [15:0] primitive_id;
  integer failures = 0;

  fpga_sid8_admission dut (
    .sid(sid),
    .admitted(admitted),
    .primitive_id(primitive_id)
  );

  task automatic expect_admitted(
    input logic [7:0] expected_sid,
    input logic [15:0] expected_primitive
  );
    begin
      sid = expected_sid;
      #1;
      if (admitted !== 1'b1 || primitive_id !== expected_primitive) begin
        $display("FAILED sid=%08b admitted=%b primitive_id=%0d expected=%0d",
                 sid, admitted, primitive_id, expected_primitive);
        failures = failures + 1;
      end
    end
  endtask

  task automatic expect_rejected(input logic [7:0] rejected_sid);
    begin
      sid = rejected_sid;
      #1;
      if (admitted !== 1'b0) begin
        $display("FAILED sid=%08b was unexpectedly admitted as primitive_id=%0d",
                 sid, primitive_id);
        failures = failures + 1;
      end
    end
  endtask

  initial begin
    // First-wave exact Sid8 -> local mechanism projection.
    expect_admitted(8'b00000101, 16'd0); // car  -> PRIM_CAR
    expect_admitted(8'b00000110, 16'd1); // cdr  -> PRIM_CDR
    expect_admitted(8'b00000100, 16'd2); // cons -> PRIM_CONS
    expect_admitted(8'b00000010, 16'd3); // atom -> PRIM_ATOM
    expect_admitted(8'b00000011, 16'd4); // eq   -> PRIM_EQ
    expect_admitted(8'b00001100, 16'd5); // +    -> PRIM_ADD

    // The stale legacy decimal 104 corresponds to 01101000, which current
    // Canon assigns elsewhere. It must not accidentally reach PRIM_ADD.
    expect_rejected(8'b01101000);

    // Unadmitted identity remains fail-closed at this FPGA boundary.
    expect_rejected(8'b11111111);

    if (failures == 0)
      $display("SID8 ADMISSION PASSED");
    else
      $display("SID8 ADMISSION FAILED: %0d failure(s)", failures);

    $finish;
  end
endmodule
