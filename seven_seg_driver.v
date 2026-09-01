module seven_seg_driver(
    input        clk,
    input        n_rst,
    input [15:0] value,
    output reg [3:0] an,
    output reg [6:0] seg
);

    reg [19:0] refresh_cnt;
    wire [1:0] digit_sel = refresh_cnt[19:18];

    reg [3:0] nibble;

    // value == FFFF면 정지 표시(F F F F)로 전환
    wire show_stop = (value == 16'hFFFF);

    // 4자리 표시라 최대 9999까지만 표시 (그 이상은 clip)
    wire [15:0] v = (value > 16'd9999) ? 16'd9999 : value;

    // 10진 자릿수 분해
    wire [3:0] digit_thousands = v / 1000;
    wire [3:0] digit_hundreds  = (v / 100) % 10;
    wire [3:0] digit_tens      = (v / 10) % 10;
    wire [3:0] digit_ones      = v % 10;


    // Refresh Counter (자리 순차 점등용)
    always @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            refresh_cnt <= 0;
        else
            refresh_cnt <= refresh_cnt + 1'b1;
    end


    // 자리 선택 (anode, active-low) + 표시할 nibble 결정
   always @(*) begin
    case (digit_sel)

        2'd0: begin
            an = 4'b1110;
            nibble = show_stop ? 4'hF : digit_thousands;
        end

        2'd1: begin
            an = 4'b1101;
            nibble = show_stop ? 4'hF : digit_hundreds;
        end

        2'd2: begin
            an = 4'b1011;
            nibble = show_stop ? 4'hF : digit_tens;
        end

        2'd3: begin
            an = 4'b0111;
            nibble = show_stop ? 4'hF : digit_ones;
        end

    endcase
end


    // 7-Segment 디코더 (active-low, cathode)
    always @(*) begin
        case (nibble)

            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;

            4'hF: seg = 7'b0001110;  // 정지 표시용 F

            default: seg = 7'b1111111;

        endcase
    end

endmodule
