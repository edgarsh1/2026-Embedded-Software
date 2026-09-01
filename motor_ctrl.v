module motor_ctrl(
    input  clk,
    input  n_rst,
    input  stop_cmd,
    output reg motor_in1,
    output reg motor_in2
);
    reg [23:0] brake_timer;
    localparam BRAKE_HOLD = 24'd10_000_000; // 100MHz 기준 약 100ms 정지 유지

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            motor_in1 <= 1'b0;
            motor_in2 <= 1'b0;
            brake_timer <= 24'd0;
        end else begin
            // stop_cmd 있는 동안 계속 재장전, 풀리면 100ms 동안 카운트다운
            if (stop_cmd) begin
                brake_timer <= BRAKE_HOLD;
            end
            else if (brake_timer > 0) begin
                brake_timer <= brake_timer - 1'b1;
            end

            // stop_cmd나 브레이크 홀드 중엔 정지, 아니면 정방향 구동
            if (stop_cmd || (brake_timer > 0)) begin
                motor_in1 <= 1'b0;
                motor_in2 <= 1'b0;
            end else begin
                motor_in1 <= 1'b1;
                motor_in2 <= 1'b0;
            end
        end
    end
endmodule
