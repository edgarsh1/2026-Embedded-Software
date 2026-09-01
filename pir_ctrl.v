module pir_ctrl(
    input  clk,
    input  n_rst,
    input  pir_out,       // PIR 센서 VOUT 신호 (비동기)
    output pir_detected   // 동기화된 감지 결과
);
    reg pir_s0, pir_s1;

    // 2단 동기화 (메타스테이블 방지)
    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            pir_s0 <= 1'b0;
            pir_s1 <= 1'b0;
        end else begin
            pir_s0 <= pir_out;
            pir_s1 <= pir_s0;
        end
    end

    assign pir_detected = pir_s1;
endmodule
