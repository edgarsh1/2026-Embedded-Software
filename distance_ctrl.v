module distance_ctrl #(
    parameter [6:0] SLAVE_ADDR   = 7'h29,
    parameter       STOP_MIN_MM  = 16'd40,    // 4cm
    parameter       STOP_MAX_MM  = 16'd150    // 15cm
)(
    input  clk,
    input  n_rst,

    output reg       m_start,
    output reg [7:0] m_reg_addr,
    output reg       m_is_write,
    output reg [7:0] m_data_in,
    input            m_busy,
    input            m_done,
    input      [7:0] m_data_out,
    input            m_ack_error,

    output reg [15:0] distance_mm,
    output            stop_cmd,
    output reg        meas_valid,
    output reg        init_done
);
    localparam REG_SYSRANGE_START = 8'h00;
    localparam REG_RANGE_HI       = 8'h1E;
    localparam REG_RANGE_LO       = 8'h1F;
    localparam REG_INT_CLEAR      = 8'h0B;

    // VL53L0X 초기화 시퀀스 (register, value) 16단계 - ST 앱노트 기준
    localparam INIT_STEPS = 16;
    reg [7:0] init_reg [0:INIT_STEPS-1];
    reg [7:0] init_val [0:INIT_STEPS-1];
    reg [4:0] init_idx;

    initial begin
        init_reg[0]=8'h89; init_val[0]=8'h00;
        init_reg[1]=8'h00; init_val[1]=8'h00;
        init_reg[2]=8'hFF; init_val[2]=8'h01;
        init_reg[3]=8'h00; init_val[3]=8'h00;
        init_reg[4]=8'hFF; init_val[4]=8'h00;
        init_reg[5]=8'h09; init_val[5]=8'h00;
        init_reg[6]=8'h10; init_val[6]=8'h00;
        init_reg[7]=8'h11; init_val[7]=8'h00;
        init_reg[8]=8'h24; init_val[8]=8'h01;
        init_reg[9]=8'h25; init_val[9]=8'hFF;
        init_reg[10]=8'h75; init_val[10]=8'h00;
        init_reg[11]=8'hFF; init_val[11]=8'h01;
        init_reg[12]=8'h4E; init_val[12]=8'h2C;
        init_reg[13]=8'h48; init_val[13]=8'h00;
        init_reg[14]=8'h30; init_val[14]=8'h20;
        init_reg[15]=8'hFF; init_val[15]=8'h00;
    end

    localparam S_BOOT     = 4'd13, S_INIT_S   = 4'd0,  S_INIT_W   = 4'd1,
               S_IDLE     = 4'd2,  S_TRIG_S   = 4'd3,  S_TRIG_W   = 4'd4,
               S_WAIT     = 4'd5,  S_RDHI_S   = 4'd6,  S_RDHI_W   = 4'd7,
               S_RDLO_S   = 4'd8,  S_RDLO_W   = 4'd9,  S_CLR_S    = 4'd10,
               S_CLR_W    = 4'd11, S_UPDATE   = 4'd12;

    reg [3:0] c_state;
    reg [7:0] hi_byte;

    reg [23:0] timer;
    reg [27:0] watchdog;

    localparam TIME_50MS  = 24'd5_000_000;
    // 주의: 이름은 30ms지만 값은 50ms로 실보드 검증 완료. 값 변경 시 재검증 필요.
    localparam TIME_30MS  = 24'd5_000_000;

    reg stop_reg;
    assign stop_cmd = stop_reg;

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            c_state <= S_BOOT;
            m_start <= 1'b0; m_reg_addr <= 8'h0; m_is_write <= 1'b0; m_data_in <= 8'h0;
            hi_byte <= 8'h0;
            timer <= 0;
            watchdog <= 0;
            stop_reg <= 1'b0; meas_valid <= 1'b0;
            init_idx <= 0; init_done <= 1'b0;
            distance_mm <= 16'hFFFF;
        end else begin
            m_start <= 1'b0;
            meas_valid <= 1'b0;

            // 워치독: BOOT/IDLE 이외 상태에서 500ms 이상 못 벗어나면 IDLE로 강제 복귀
            // (I2C 마스터가 어떤 이유로든 응답을 안 줄 때 FSM이 영구적으로 멈추는 것 방지)
            if (c_state != S_BOOT && c_state != S_IDLE) begin
                watchdog <= watchdog + 1'b1;
                if (watchdog >= 28'd50_000_000) begin
                    watchdog <= 0;
                    c_state <= S_IDLE;
                end
            end else begin
                watchdog <= 0;
            end

            case (c_state)
                S_BOOT: begin
                    timer <= timer + 1'b1;
                    if (timer >= TIME_50MS) begin
                        timer <= 0;
                        c_state <= S_INIT_S;
                    end
                end

                S_INIT_S: begin
                    if (!m_busy) begin
                        m_reg_addr <= init_reg[init_idx];
                        m_data_in  <= init_val[init_idx];
                        m_is_write <= 1'b1;
                        m_start    <= 1'b1;
                        c_state    <= S_INIT_W;
                    end
                end
                S_INIT_W: if (m_done) begin
                    if (init_idx == INIT_STEPS-1) begin
                        init_done <= 1'b1;
                        c_state   <= S_IDLE;
                    end else begin
                        init_idx <= init_idx + 1'b1;
                        c_state  <= S_INIT_S;
                    end
                end

                S_IDLE: begin
                    timer <= timer + 1'b1;
                    if (timer >= TIME_50MS) begin
                        timer <= 0;
                        c_state <= S_TRIG_S;
                    end
                end

                // 측정 트리거: SYSRANGE_START 레지스터에 1 write
                S_TRIG_S: begin
                    if (!m_busy) begin
                        m_reg_addr <= REG_SYSRANGE_START;
                        m_is_write <= 1'b1;
                        m_data_in  <= 8'h01;
                        m_start    <= 1'b1;
                        c_state    <= S_TRIG_W;
                    end
                end
                S_TRIG_W: if (m_done) begin
                    if (m_ack_error) c_state <= S_IDLE;
                    else c_state <= S_WAIT;
                end

                // 측정 완료 대기
                S_WAIT: begin
                    timer <= timer + 1'b1;
                    if (timer >= TIME_30MS) begin
                        timer <= 0;
                        c_state <= S_RDHI_S;
                    end
                end

                // 거리값 상위 바이트 read
                S_RDHI_S: begin
                    if (!m_busy) begin
                        m_reg_addr <= REG_RANGE_HI;
                        m_is_write <= 1'b0;
                        m_start    <= 1'b1;
                        c_state    <= S_RDHI_W;
                    end
                end
                S_RDHI_W: if (m_done) begin
                    if (m_ack_error) c_state <= S_IDLE;
                    else begin hi_byte <= m_data_out; c_state <= S_RDLO_S; end
                end

                // 거리값 하위 바이트 read
                S_RDLO_S: begin
                    if (!m_busy) begin
                        m_reg_addr <= REG_RANGE_LO;
                        m_is_write <= 1'b0;
                        m_start    <= 1'b1;
                        c_state    <= S_RDLO_W;
                    end
                end
                S_RDLO_W: if (m_done) begin
                    if (m_ack_error) c_state <= S_IDLE;
                    else begin
                        distance_mm <= {hi_byte, m_data_out};
                        c_state <= S_CLR_S;
                    end
                end

                // 인터럽트 클리어 (다음 측정 준비)
                S_CLR_S: begin
                    if (!m_busy) begin
                        m_reg_addr <= REG_INT_CLEAR;
                        m_is_write <= 1'b1;
                        m_data_in  <= 8'h01;
                        m_start    <= 1'b1;
                        c_state    <= S_CLR_W;
                    end
                end
                S_CLR_W: if (m_done) c_state <= S_UPDATE;

                // 정지 판정: 데드존(4~15cm) 안에 들어오면 stop_cmd=1
                S_UPDATE: begin
                    meas_valid <= 1'b1;
                    if (distance_mm >= STOP_MIN_MM && distance_mm <= STOP_MAX_MM)
                        stop_reg <= 1'b1;
                    else
                        stop_reg <= 1'b0;
                    c_state <= S_IDLE;
                end
                default: c_state <= S_IDLE;
            endcase
        end
    end
endmodule
