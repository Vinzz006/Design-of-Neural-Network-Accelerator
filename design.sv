
`timescale 1ns/1ps

module neural_network_accelerator (
    input wire clk,
    input wire rst,
    input wire start,

    input wire signed [7:0] x0,
    input wire signed [7:0] x1,
    input wire signed [7:0] x2,
    input wire signed [7:0] x3,

    output reg signed [31:0] y0,
    output reg signed [31:0] y1,
    output reg busy,
    output reg done
);

    localparam IDLE    = 3'd0;
    localparam COMPUTE = 3'd1;
    localparam CAPTURE = 3'd2;
    localparam NEXT    = 3'd3;
    localparam FINISH  = 3'd4;

    reg [2:0] state;
    reg [1:0] index;
    reg neuron;

    reg signed [7:0] selected_input;
    reg signed [7:0] selected_weight;

    wire signed [15:0] product;
    reg signed [31:0] accumulator;
    wire signed [31:0] activated;

    // Select one input at a time.
    always @(*) begin
        case (index)
            2'd0: selected_input = x0;
            2'd1: selected_input = x1;
            2'd2: selected_input = x2;
            2'd3: selected_input = x3;
            default: selected_input = 8'sd0;
        endcase
    end

    // Weights for two neurons.
    // Neuron 0: [1, -1, 2, 1]
    // Neuron 1: [1,  2, -1, 1]
    always @(*) begin
        selected_weight = 8'sd0;

        case (neuron)
            1'b0: begin
                case (index)
                    2'd0: selected_weight =  8'sd1;
                    2'd1: selected_weight = -8'sd1;
                    2'd2: selected_weight =  8'sd2;
                    2'd3: selected_weight =  8'sd1;
                endcase
            end

            1'b1: begin
                case (index)
                    2'd0: selected_weight =  8'sd1;
                    2'd1: selected_weight =  8'sd2;
                    2'd2: selected_weight = -8'sd1;
                    2'd3: selected_weight =  8'sd1;
                endcase
            end
        endcase
    end

    // Multiply input by selected weight.
    assign product = selected_input * selected_weight;

    // ReLU activation.
    assign activated =
        (accumulator < 0) ? 32'sd0 : accumulator;

    // FSM and datapath.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            index       <= 2'd0;
            neuron      <= 1'b0;
            accumulator <= 32'sd0;
            y0          <= 32'sd0;
            y1          <= 32'sd0;
            busy        <= 1'b0;
            done        <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)

                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        index       <= 2'd0;
                        neuron      <= 1'b0;
                        accumulator <= 32'sd0;
                        busy        <= 1'b1;
                        state       <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    accumulator <= accumulator
                                 + {{16{product[15]}}, product};

                    if (index == 2'd3)
                        state <= CAPTURE;
                    else
                        index <= index + 1'b1;
                end

                CAPTURE: begin
                    state <= NEXT;
                end

                NEXT: begin
                    if (neuron == 1'b0) begin
                        y0          <= activated;
                        neuron      <= 1'b1;
                        index       <= 2'd0;
                        accumulator <= 32'sd0;
                        state       <= COMPUTE;
                    end else begin
                        y1    <= activated;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state       <= IDLE;
                    index       <= 2'd0;
                    neuron      <= 1'b0;
                    accumulator <= 32'sd0;
                    busy        <= 1'b0;
                    done        <= 1'b0;
                end

            endcase
        end
    end

endmodule
