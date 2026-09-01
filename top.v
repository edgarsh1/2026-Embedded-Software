module top(
    input  clk,
    input  btn_rst,
    input  pir_out,
    input  uart_rxd,

    output busy,
    output ack_error,
    output [3:0] seg_an,
    output [6:0] seg_cg,
    output scl,
    inout  sda,
    output init_led,
    output motor_in1,
    output motor_in2,
    output pir_led,
    output cam_led
);

    wire init_done;
    wire n_rst = ~btn_rst;

    localparam [6:0] SLAVE_ADDR = 7'h29;

    wire        m_start;
    wire        m_is_write;
    wire        m_busy;
    wire        m_done;
    wire        m_ack_error;

    wire [7:0]  m_reg_addr;
    wire [7:0]  m_data_in;
    wire [7:0]  m_data_out;

    wire [15:0] distance_mm;
    wire        stop_cmd_dist;
    wire        meas_valid;
    wire        pir_detected;


    //==================================================
    // I2C Master (VL53L0X와 통신, addr 0x29)
    //==================================================
    i2c_master #(
        .DIVIDE(1000)
    ) u_master (
        .clk(clk),
        .n_rst(n_rst),

        .start(m_start),
        .slave_addr(SLAVE_ADDR),
        .reg_addr(m_reg_addr),
        .is_write(m_is_write),
        .data_in(m_data_in),

        .data_out(m_data_out),
        .busy(m_busy),
        .done(m_done),
        .ack_error(m_ack_error),

        .scl(scl),
        .sda(sda)
    );


    //==================================================
    // 거리 센서 (VL53L0X 초기화 + 측정 + 정지 판정)
    //==================================================
    distance_ctrl #(
        .STOP_MIN_MM(40),
        .STOP_MAX_MM(150)
    ) u_dist (
        .clk(clk),
        .n_rst(n_rst),

        .m_start(m_start),
        .m_reg_addr(m_reg_addr),
        .m_is_write(m_is_write),
        .m_data_in(m_data_in),

        .m_busy(m_busy),
        .m_done(m_done),
        .m_data_out(m_data_out),
        .m_ack_error(m_ack_error),

        .distance_mm(distance_mm),
        .stop_cmd(stop_cmd_dist),
        .meas_valid(meas_valid),
        .init_done(init_done)
    );


    //==================================================
    // PIR 센서
    //==================================================
    pir_ctrl u_pir (
        .clk(clk),
        .n_rst(n_rst),

        .pir_out(pir_out),
        .pir_detected(pir_detected)
    );


    //==================================================
    // UART RX (라즈베리파이 카메라 판정 결과 수신)
    //==================================================
    wire [7:0] rx_data;
    wire       rx_done;

    uart_rx u_rx (
        .clk(clk),
        .n_rst(n_rst),

        .uart_rxd(uart_rxd),
        .rx_data(rx_data),
        .done(rx_done)
    );


    //==================================================
    // 카메라 판정 래치 (0xA5=정지, 0x00=해제)
    //==================================================
    reg cam_stop;

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            cam_stop <= 1'b0;
        end
        else if (rx_done) begin
            if (rx_data == 8'hA5)
                cam_stop <= 1'b1;
            else if (rx_data == 8'h00)
                cam_stop <= 1'b0;
        end
    end


    //==================================================
    // 2oo3 보팅: 거리/PIR/카메라 중 2개 이상 일치 시 정지
    //==================================================
    wire stop_cmd;

    assign stop_cmd =
           (stop_cmd_dist & pir_detected) |
           (stop_cmd_dist & cam_stop)     |
           (pir_detected  & cam_stop);


    //==================================================
    // 모터 제어 (L298N IN1/IN2)
    //==================================================
    motor_ctrl u_motor (
        .clk(clk),
        .n_rst(n_rst),

        .stop_cmd(stop_cmd),

        .motor_in1(motor_in1),
        .motor_in2(motor_in2)
    );


    //==================================================
    // 7세그먼트 표시: 평상시 거리(mm), 정지 시 FFFF
    //==================================================
    wire [15:0] display_value;

    assign display_value = stop_cmd ? 16'hFFFF : distance_mm;

    seven_seg_driver u_seg (
        .clk(clk),
        .n_rst(n_rst),

        .value(display_value),

        .an(seg_an),
        .seg(seg_cg)
    );


    //==================================================
    // 상태 LED 출력
    //==================================================
    assign busy      = m_busy;
    assign ack_error = m_ack_error;
    assign init_led  = init_done;
    assign pir_led   = pir_detected;
    assign cam_led   = cam_stop;

endmodule
