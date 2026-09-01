# -------------------------------------------------------------------------
# Basys 3 Master XDC File (Cleaned)
# -------------------------------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# -------------------------------------------------------------------------
# 1. Clock (100MHz)
# -------------------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# -------------------------------------------------------------------------
# 2. Reset Button
# -------------------------------------------------------------------------
# BTNC (중앙 버튼) - 리셋
set_property PACKAGE_PIN U18 [get_ports btn_rst]
set_property IOSTANDARD LVCMOS33 [get_ports btn_rst]

# -------------------------------------------------------------------------
# 3. Status LEDs
# -------------------------------------------------------------------------
# LED 0 (I2C busy 표시 - 깜빡임)
set_property PACKAGE_PIN U16 [get_ports busy]
set_property IOSTANDARD LVCMOS33 [get_ports busy]

# LED 3 (I2C 에러 발생)
set_property PACKAGE_PIN U19 [get_ports ack_error]
set_property IOSTANDARD LVCMOS33 [get_ports ack_error]

# LED 15 (초기화 완료 - 항상 켜져 있어야 정상)
set_property PACKAGE_PIN V19 [get_ports init_led]
set_property IOSTANDARD LVCMOS33 [get_ports init_led]

# PIR 감지 상태 표시용 LED (LED 14번)
set_property PACKAGE_PIN P1 [get_ports pir_led]
set_property IOSTANDARD LVCMOS33 [get_ports pir_led]

# 카메라 정지 판정 확인용 LED
set_property PACKAGE_PIN V3 [get_ports cam_led]
set_property IOSTANDARD LVCMOS33 [get_ports cam_led]

# -------------------------------------------------------------------------
# 4. Pmod JA & 기타 핀 (센서, 모터, UART)
# -------------------------------------------------------------------------
# JA 1번 핀: 거리센서 SCL
set_property PACKAGE_PIN J1 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports scl]

# JA 2번 핀: 거리센서 SDA
set_property PACKAGE_PIN L2 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]

# JA 3번 핀: 모터 IN1
set_property PACKAGE_PIN J2 [get_ports motor_in1]
set_property IOSTANDARD LVCMOS33 [get_ports motor_in1]

# JA 4번 핀: 모터 IN2
set_property PACKAGE_PIN G2 [get_ports motor_in2]
set_property IOSTANDARD LVCMOS33 [get_ports motor_in2]

# PIR 감지 입력 (JA 포트 중 남는 핀 사용)
set_property PACKAGE_PIN J3 [get_ports pir_out]
set_property IOSTANDARD LVCMOS33 [get_ports pir_out]

# UART RX (라즈베리파이 TX 연결, 별도 핀헤더 사용 - Pmod JA 아님)
set_property PACKAGE_PIN A14 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]

# -------------------------------------------------------------------------
# 5. 7-Segment Display
# -------------------------------------------------------------------------
# Segments (a, b, c, d, e, f, g)
set_property PACKAGE_PIN W7 [get_ports {seg_cg[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg_cg[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg_cg[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg_cg[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg_cg[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg_cg[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg_cg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cg[6]}]

# Anodes (자리 선택)
set_property PACKAGE_PIN W4 [get_ports {seg_an[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_an[0]}]
set_property PACKAGE_PIN V4 [get_ports {seg_an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_an[1]}]
set_property PACKAGE_PIN U4 [get_ports {seg_an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_an[2]}]
set_property PACKAGE_PIN U2 [get_ports {seg_an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_an[3]}]
