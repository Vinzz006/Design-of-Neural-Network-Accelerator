
`timescale 1ns/1ps

module testbench;

    reg clk;
    reg rst;
    reg start;

    reg signed [7:0] x0, x1, x2, x3;

    wire signed [31:0] y0, y1;
    wire busy, done;

    integer passed;
    integer failed;
    integer count;

    neural_network_accelerator dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .x0(x0),
        .x1(x1),
        .x2(x2),
        .x3(x3),
        .y0(y0),
        .y1(y1),
        .busy(busy),
        .done(done)
    );

    // Generate clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Start the accelerator and wait for completion
    task run_test;
    begin
        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        count = 0;

        while ((done !== 1'b1) && (count < 30)) begin
            @(negedge clk);
            count = count + 1;
        end

        #1;

        if (done !== 1'b1) begin
            $display("ERROR: Accelerator timeout");
            failed = failed + 1;
        end
    end
    endtask

    // Compare actual outputs with expected outputs
    task check_result;
        input signed [31:0] expected_y0;
        input signed [31:0] expected_y1;
    begin
        $display("----------------------------------------");
        $display("Inputs: [%0d, %0d, %0d, %0d]",
                 x0, x1, x2, x3);
        $display("Actual:   y0 = %0d, y1 = %0d", y0, y1);
        $display("Expected: y0 = %0d, y1 = %0d",
                 expected_y0, expected_y1);

        if ((y0 === expected_y0) &&
            (y1 === expected_y1)) begin
            $display("RESULT: TEST PASSED");
            passed = passed + 1;
        end
        else begin
            $display("RESULT: TEST FAILED");
            failed = failed + 1;
        end
    end
    endtask

    // Main test sequence
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;

        x0 = 0;
        x1 = 0;
        x2 = 0;
        x3 = 0;

        passed = 0;
        failed = 0;

        // Apply reset
        repeat (3) @(negedge clk);
        rst = 1'b0;

        // TEST 1: Positive outputs
        @(negedge clk);
        x0 = 2;
        x1 = 3;
        x2 = 1;
        x3 = 4;

        run_test;
        check_result(32'sd5, 32'sd11);

        // TEST 2: Negative sums; ReLU should output zero
        @(negedge clk);
        x0 = -10;
        x1 = 0;
        x2 = -3;
        x3 = -4;

        run_test;
        check_result(32'sd0, 32'sd0);

        // TEST 3: All inputs are zero
        @(negedge clk);
        x0 = 0;
        x1 = 0;
        x2 = 0;
        x3 = 0;

        run_test;
        check_result(32'sd0, 32'sd0);

        // Display final summary
        $display("");
        $display("========================================");
        $display("         SIMULATION SUMMARY");
        $display("========================================");
        $display("Tests passed: %0d", passed);
        $display("Tests failed: %0d", failed);

        if ((passed == 3) && (failed == 0))
            $display("OVERALL RESULT: ALL TESTS PASSED");
        else
            $display("OVERALL RESULT: SOME TESTS FAILED");

        $display("========================================");

        $finish;
    end

    // Global timeout
    initial begin
        #5000;
        $display("ERROR: Global simulation timeout");
        $finish;
    end

endmodule
