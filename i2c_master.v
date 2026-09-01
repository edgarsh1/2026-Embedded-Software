module i2c_master #(
    parameter integer DIVIDE = 1000  // SCL = clk / DIVIDE (100MHz/1000 = 100kHz 주기, 50kHz SCL)
)(
    input        clk,
    input        n_rst,
    input        start,
    input  [6:0] slave_addr,
    input  [7:0] reg_addr,
    input        is_write,
    input  [7:0] data_in,

    output reg [7:0] data_out,
    output           busy,
    output reg       done,
    output reg       ack_error,
    output           scl,
    inout            sda
);
    // Repeated START 지원: write(주소+레지스터) -> restart -> read(주소+데이터) -> stop
    // 버튼 1번으로 전체 시퀀스 자동 수행 (기존 3버튼 방식은 중간에 STOP이 끼어 레지스터 포인터가 풀리는 문제가 있어 폐기)
    localparam [3:0]
        S_IDLE        = 4'd0,
        S_START       = 4'd1,
        S_ADDR_W      = 4'd2,
        S_ACK_AW      = 4'd3,
        S_REG         = 4'd4,
         S_ACK_REG     = 4'd5,
         S_WDATA       = 4'd6,
         S_ACK_WDATA   = 4'd7,
        S_RESTART_PRE = 4'd8,
        S_RESTART     = 4'd9,
         S_ADDR_R      = 4'd10,
         S_ACK_AR      = 4'd11,
        S_READ        = 4'd12,
        S_NACK        = 4'd13,
        S_STOP        = 4'd14,
        S_DONE        = 4'd15;

    reg [3:0] c_state;
    reg       scl_reg, sda_out;
    reg [2:0] bit_idx;
    reg [7:0] tx_shift, rx_shift;
    reg       is_write_r;
    reg sda_s0, sda_s1;

    // 2단 동기화: SDA는 슬레이브가 구동하는 비동기 입력이라 메타스테이블 방지 필요
    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin sda_s0<=1'b1; sda_s1<=1'b1; end
        else        begin sda_s0<=sda;  sda_s1<=sda_s0; end
    end

    wire sda_in = sda_s1;
    assign scl = scl_reg;
    // 오픈드레인: low만 직접 구동, 그 외엔 하이임피던스 (풀업 저항이 high로 끌어올림)
    assign sda = (sda_out == 1'b0) ? 1'b0 : 1'bz;
    assign busy = (c_state != S_IDLE);

    // 4-phase 클록 생성: 한 SCL 주기를 phase 0~3로 나눠서 SDA/SCL 타이밍 제어
    reg [15:0] tick_cnt;
    wire tick = (tick_cnt == (DIVIDE/2) - 1);

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) tick_cnt <= 0;
        else if (c_state == S_IDLE || tick) tick_cnt <= 0;
        else tick_cnt <= tick_cnt + 1'b1;
    end

    reg [1:0] phase;
    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) phase <= 0;
        else if (c_state == S_IDLE) phase <= 0;
        else if (tick) phase <= phase + 1'b1;
    end

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            c_state <= S_IDLE; scl_reg <= 1'b1; sda_out <= 1'b1;
            bit_idx <= 3'd7; tx_shift <= 8'h0; rx_shift <= 8'h0;
            ack_error <= 1'b0; done <= 1'b0; data_out <= 8'h0; is_write_r <= 1'b0;
        end else begin
            done <= 1'b0;
            if (c_state == S_IDLE) begin
                scl_reg <= 1'b1; sda_out <= 1'b1;
                if (start) begin
                    c_state <= S_START;
                    tx_shift <= {slave_addr, 1'b0};
                    is_write_r <= is_write;
                    ack_error <= 1'b0;
                end
            end
            else if (tick) begin
                case (c_state)
                    // START 조건: SCL high일 때 SDA를 low로 (SCL 12=1->0 순서 확인)
                    S_START: begin
                        if      (phase == 2'd0) {scl_reg, sda_out} <= 2'b11;
                        else if (phase == 2'd1) {scl_reg, sda_out} <= 2'b10;
                        else if (phase == 2'd3) begin
                            {scl_reg, sda_out} <= 2'b00;
                            c_state <= S_ADDR_W; bit_idx <= 3'd7;
                        end
                    end
                    // 1비트 shift-out (주소/레지스터/데이터 공용): SCL low에서 SDA 세팅 -> high -> 다음 비트
                    S_ADDR_W, S_REG, S_ADDR_R, S_WDATA: begin
                        if      (phase == 2'd0) begin scl_reg <= 1'b0; sda_out <= tx_shift[bit_idx]; end
                        else if (phase == 2'd1) scl_reg <= 1'b1;
                        else if (phase == 2'd3) begin
                            scl_reg <= 1'b0;
                            if (bit_idx == 3'd0) begin
                                if      (c_state == S_ADDR_W) c_state <= S_ACK_AW;
                                else if (c_state == S_REG)    c_state <= S_ACK_REG;
                                else if (c_state == S_WDATA)  c_state <= S_ACK_WDATA;
                                else                          c_state <= S_ACK_AR;
                            end else bit_idx <= bit_idx - 1'b1;
                        end
                    end
                    // ACK 확인: SCL high 구간(phase 2)에서 SDA 샘플 -> high면 NACK
                    S_ACK_AW, S_ACK_REG, S_ACK_AR, S_ACK_WDATA: begin
                        if      (phase == 2'd0) begin scl_reg <= 1'b0; sda_out <= 1'b1; end
                        else if (phase == 2'd1) scl_reg <= 1'b1;
                        else if (phase == 2'd2) begin
                            if (sda_in == 1'b1) ack_error <= 1'b1;
                        end
                        else if (phase == 2'd3) begin
                            scl_reg <= 1'b0;
                            if (ack_error || sda_in) c_state <= S_STOP;
                            else if (c_state == S_ACK_AW) begin
                                c_state <= S_REG; tx_shift <= reg_addr; bit_idx <= 3'd7;
                            end
                            else if (c_state == S_ACK_REG) begin
                                if (is_write_r) begin
                                    c_state <= S_WDATA; tx_shift <= data_in; bit_idx <= 3'd7;
                                end else c_state <= S_RESTART_PRE;
                            end
                            else if (c_state == S_ACK_WDATA) c_state <= S_STOP;
                            else if (c_state == S_ACK_AR) begin
                                c_state <= S_READ; bit_idx <= 3'd7;
                            end
                        end
                    end
                    S_RESTART_PRE: begin
                        if      (phase == 2'd0) begin scl_reg <= 1'b0; sda_out <= 1'b1; end
                        else if (phase == 2'd3) c_state <= S_RESTART;
                    end
                    // Repeated START: STOP 없이 바로 재시작 (read 페이즈로 전환, 레지스터 포인터 유지)
                    S_RESTART: begin
                        if      (phase == 2'd0) {scl_reg, sda_out} <= 2'b11;
                        else if (phase == 2'd1) {scl_reg, sda_out} <= 2'b10;
                        else if (phase == 2'd3) begin
                            {scl_reg, sda_out} <= 2'b00;
                            c_state <= S_ADDR_R; tx_shift <= {slave_addr, 1'b1}; bit_idx <= 3'd7;
                        end
                    end
                    // 1비트 shift-in
                    S_READ: begin
                        if      (phase == 2'd0) begin scl_reg <= 1'b0; sda_out <= 1'b1; end
                        else if (phase == 2'd1) scl_reg <= 1'b1;
                        else if (phase == 2'd2) rx_shift[bit_idx] <= sda_in;
                        else if (phase == 2'd3) begin
                            scl_reg <= 1'b0;
                            if (bit_idx == 3'd0) c_state <= S_NACK;
                            else                 bit_idx <= bit_idx - 1'b1;
                        end
                    end
                    // 마지막 바이트는 NACK로 응답 (싱글 read 종료 신호)
                    S_NACK: begin
                        if      (phase == 2'd0) begin scl_reg <= 1'b0; sda_out <= 1'b1; end
                        else if (phase == 2'd1) scl_reg <= 1'b1;
                        else if (phase == 2'd3) begin
                            scl_reg <= 1'b0; data_out <= rx_shift; c_state <= S_STOP;
                        end
                    end
                    // STOP 조건: SCL high일 때 SDA low->high
                    S_STOP: begin
                        if      (phase == 2'd0) {scl_reg, sda_out} <= 2'b00;
                        else if (phase == 2'd1) {scl_reg, sda_out} <= 2'b10;
                        else if (phase == 2'd2) {scl_reg, sda_out} <= 2'b11;
                        else if (phase == 2'd3) begin done <= 1'b1; c_state <= S_DONE; end
                    end
                    S_DONE: c_state <= S_IDLE;
                endcase
            end
        end
    end
endmodule
