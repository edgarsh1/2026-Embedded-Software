module uart_rx (
    input            clk,
    input            n_rst,
    input            uart_rxd,   // UART RX 시리얼 입력 (비동기, 라즈베리파이 TX 연결)
    output reg [7:0] rx_data,    // 수신된 8비트 데이터
    output reg       done        // 1클럭 동안 수신 완료 펄스
);
  reg rxin_d1;
  reg rxin_d2;
  reg rxin_d3;
  wire start_en;
  reg  rx_en;
  reg [12:0] cnt;
  reg [3:0]  cnt_bit;
  wire       clk_rx_en;

  // 100MHz 기준 19200bps: 1비트 구간 = 5208 클럭 (T_DIV), 중간 샘플링 지점 = T_HALF
  parameter T_DIV  = 13'd5207;
  parameter T_HALF = 13'd2603;

  // 3단 동기화 (메타스테이블 방지 2단 + 엣지 검출용 1단)
  always @(posedge clk or negedge n_rst)
    if (!n_rst) begin
      rxin_d1 <= 1'b1;
      rxin_d2 <= 1'b1;
      rxin_d3 <= 1'b1;
    end else begin
      rxin_d1 <= uart_rxd;
      rxin_d2 <= rxin_d1;
      rxin_d3 <= rxin_d2;
    end

  // 하강 엣지 검출 = start bit 시작
  assign start_en = (rxin_d2 == 1'b0 && rxin_d3 == 1'b1) ? 1'b1 : 1'b0;

  // 수신 진행 중 플래그: start 감지 시 켜지고 done 되면 꺼짐
  always @(posedge clk or negedge n_rst)
    if (!n_rst) begin
      rx_en <= 1'b0;
    end else begin
      rx_en <= (start_en == 1'b1 && rx_en == 1'b0) ? 1'b1 : (done == 1'b1) ? 1'b0 : rx_en;
    end

  // 비트 구간 카운터 (T_DIV마다 다음 비트로)
  always @(posedge clk or negedge n_rst)
    if (!n_rst) begin
      cnt <= 13'h0000;
    end else begin
      if (rx_en == 1'b1) begin
        cnt <= (cnt == T_DIV) ? 13'h0000 : cnt + 13'h0001;
      end else begin
        cnt <= 13'h0000;
      end
    end

  // 비트 중간 지점에서 샘플링 (엣지 근처 노이즈 회피)
  assign clk_rx_en = (cnt == T_HALF) ? 1'b1 : 1'b0;

  // 비트 인덱스: 0=start, 1~8=data, 9=stop
  always @(posedge clk or negedge n_rst)
    if (!n_rst) begin
      cnt_bit <= 4'h0;
    end else begin
      if (rx_en == 1'b1) begin
        if (cnt == T_DIV) begin
          cnt_bit <= (cnt_bit == 4'd9) ? 4'b0000 : cnt_bit + 4'b0001;
        end
      end else begin
        cnt_bit <= 4'h0;
      end
    end

  // 데이터 비트(1~8) LSB부터 시프트인
  always @(posedge clk or negedge n_rst)
    if (!n_rst) begin
      rx_data <= 8'h00;
    end else begin
      if (rx_en == 1'b1 && clk_rx_en == 1'b1) begin
        if (cnt_bit >= 4'd1 && cnt_bit <= 4'd8) begin
          rx_data <= {rxin_d3, rx_data[7:1]};
        end else begin
          rx_data <= rx_data;
        end
      end
    end

  // stop bit 위치(9)에서 1클럭 완료 펄스
  always @(posedge clk or negedge n_rst)
    if (!n_rst) begin
      done <= 1'b0;
    end else begin
      done <= (cnt_bit == 4'd9 && cnt == T_DIV) ? 1'b1 : 1'b0;
    end
endmodule
