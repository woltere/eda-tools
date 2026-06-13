module top (
    input  wire clk_27mhz,
    input  wire reset_n,
    output wire uart_tx
);

    localparam integer CLOCK_HZ        = 27_000_000;
    localparam integer BAUD_RATE       = 115_200;
    localparam [2:0]  STATE_PREPARE      = 3'd0;
    localparam [2:0]  STATE_LAUNCH       = 3'd1;
    localparam [2:0]  STATE_WAIT_BUSY    = 3'd2;
    localparam [2:0]  STATE_WAIT_IDLE    = 3'd3;
    localparam [2:0]  STATE_REPEAT_DELAY = 3'd4;
    localparam [4:0]  LAST_MESSAGE_INDEX = 5'd23;
    localparam [4:0]  MESSAGE_DONE       = 5'd24;
    localparam integer REPEAT_DELAY_CLKS = CLOCK_HZ;

    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;

    reg [2:0]  state;
    reg [4:0]  message_index;
    reg [31:0] repeat_countdown;

    uart_tx #(
        .CLKS_PER_BIT(CLOCK_HZ / BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk_27mhz),
        .reset_n(reset_n),
        .start(tx_start),
        .data(tx_data),
        .tx(uart_tx),
        .busy(tx_busy)
    );

    function [7:0] message_byte;
        input [4:0] index;
        begin
            case (index)
                5'd0:  message_byte = "H";
                5'd1:  message_byte = "e";
                5'd2:  message_byte = "l";
                5'd3:  message_byte = "l";
                5'd4:  message_byte = "o";
                5'd5:  message_byte = " ";
                5'd6:  message_byte = "f";
                5'd7:  message_byte = "r";
                5'd8:  message_byte = "o";
                5'd9:  message_byte = "m";
                5'd10: message_byte = " ";
                5'd11: message_byte = "P";
                5'd12: message_byte = "r";
                5'd13: message_byte = "i";
                5'd14: message_byte = "m";
                5'd15: message_byte = "e";
                5'd16: message_byte = "r";
                5'd17: message_byte = " ";
                5'd18: message_byte = "2";
                5'd19: message_byte = "0";
                5'd20: message_byte = "K";
                5'd21: message_byte = "!";
                5'd22: message_byte = 8'h0d;
                5'd23: message_byte = 8'h0a;
                default: message_byte = 8'h00;
            endcase
        end
    endfunction

    always @(posedge clk_27mhz or negedge reset_n) begin
        if (!reset_n) begin
            tx_start         <= 1'b0;
            tx_data          <= 8'h00;
            state            <= STATE_PREPARE;
            message_index    <= 5'd0;
            repeat_countdown <= 32'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)
                STATE_PREPARE: begin
                    if (message_index == MESSAGE_DONE) begin
                        state <= STATE_REPEAT_DELAY;
                    end else if (!tx_busy) begin
                        tx_data <= message_byte(message_index);
                        state   <= STATE_LAUNCH;
                    end
                end

                STATE_LAUNCH: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        state    <= STATE_WAIT_BUSY;

                        if (message_index == LAST_MESSAGE_INDEX) begin
                            message_index    <= MESSAGE_DONE;
                            repeat_countdown <= REPEAT_DELAY_CLKS;
                        end else begin
                            message_index <= message_index + 5'd1;
                        end
                    end
                end

                STATE_WAIT_BUSY: begin
                    if (tx_busy) begin
                        state <= STATE_WAIT_IDLE;
                    end
                end

                STATE_WAIT_IDLE: begin
                    if (!tx_busy) begin
                        state <= STATE_PREPARE;
                    end
                end

                STATE_REPEAT_DELAY: begin
                    if (repeat_countdown != 0) begin
                        repeat_countdown <= repeat_countdown - 32'd1;
                    end else begin
                        message_index <= 5'd0;
                        state         <= STATE_PREPARE;
                    end
                end

                default: begin
                    state <= STATE_PREPARE;
                end
            endcase
        end
    end

endmodule
