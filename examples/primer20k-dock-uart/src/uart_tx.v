module uart_tx #(
    parameter integer CLKS_PER_BIT = 234
) (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx,
    output reg        busy
);

    localparam [1:0] STATE_IDLE  = 2'd0;
    localparam [1:0] STATE_START = 2'd1;
    localparam [1:0] STATE_DATA  = 2'd2;
    localparam [1:0] STATE_STOP  = 2'd3;
    localparam integer LAST_CLK_COUNT = CLKS_PER_BIT - 1;

    reg [1:0] state;
    reg [7:0] shifter;
    reg [2:0] bit_index;
    reg [31:0] clk_count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state     <= STATE_IDLE;
            shifter   <= 8'h00;
            bit_index <= 3'd0;
            clk_count <= 32'd0;
            tx        <= 1'b1;
            busy      <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx        <= 1'b1;
                    busy      <= 1'b0;
                    clk_count <= 32'd0;
                    bit_index <= 3'd0;

                    if (start) begin
                        shifter <= data;
                        busy    <= 1'b1;
                        state   <= STATE_START;
                        tx      <= 1'b0;
                    end
                end

                STATE_START: begin
                    if (clk_count == LAST_CLK_COUNT) begin
                        clk_count <= 32'd0;
                        state     <= STATE_DATA;
                        tx        <= shifter[0];
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                STATE_DATA: begin
                    if (clk_count == LAST_CLK_COUNT) begin
                        clk_count <= 32'd0;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= STATE_STOP;
                            tx        <= 1'b1;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                            shifter   <= {1'b0, shifter[7:1]};
                            tx        <= shifter[1];
                        end
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                STATE_STOP: begin
                    if (clk_count == LAST_CLK_COUNT) begin
                        clk_count <= 32'd0;
                        state     <= STATE_IDLE;
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
