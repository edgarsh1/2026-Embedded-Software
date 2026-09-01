# 컨베이어 근접정지 시스템 (2oo3 보팅 기반)

임베디드SW경진대회 자유공모 출품작. FPGA(Basys3)를 메인 컨트롤러로 쓰고 라즈베리파이5는 카메라 색상분류만 담당하는 구조. 거리센서(VL53L0X) + PIR + 카메라, 세 신호 중 2개 이상 일치할 때만 컨베이어를 정지시키는 2oo3(2-out-of-3) 보팅으로 오탐을 줄였다.

## 하드웨어 구성

- **Basys3 (Xilinx Artix-7, xc7a35t)** — 메인 컨트롤러, 2oo3 판단과 모터 제어를 전부 담당
- **VL53L0X** — I2C 거리센서(addr 0x29), Pmod JA1/JA2에 연결
- **PIR (HC-SR501)** — 인체감지, 디지털 입력 1핀
- **라즈베리파이5 + 카메라** — 벨트 위 피부색 검출(OpenCV HSV), UART로 FPGA에 정지 여부만 전송(0xA5=정지, 0x00=해제)
- **L298N + DC모터** — 컨베이어 벨트 구동, IN1/IN2를 Pmod JA3/JA4에 연결 (VL53L0X와 같은 JA 포트 공유)
- **7세그먼트** — 평상시 거리(mm) 표시, 정지 시 `FFFF` 표시

## 동작 방식

1. VL53L0X가 I2C로 거리를 주기적으로 측정 (Repeated START 지원 I2C 마스터, 50kHz SCL)
2. 거리가 4~15cm 데드존에 들어오면 `stop_cmd_dist` = 1
3. PIR은 2단 동기화 후 그대로 `pir_detected`로 사용
4. 라즈베리파이가 UART로 보낸 카메라 판정 결과를 `cam_stop`으로 래치
5. 세 신호 중 2개 이상 일치하면 `stop_cmd` = 1 → 모터 정지, 100ms 브레이크 홀드 후 재개

## 파일 구성

| 파일 | 역할 |
|---|---|
| `top.v` | 최상위 모듈, 서브모듈 연결 + 2oo3 보팅 로직 |
| `i2c_master.v` | I2C 마스터 (Repeated START 지원, 4-phase 타이밍 FSM) |
| `distance_ctrl.v` | VL53L0X 초기화 시퀀스 + 측정 루프 + 정지 판정, 워치독 포함 |
| `pir_ctrl.v` | PIR 입력 2단 동기화 |
| `motor_ctrl.v` | L298N IN1/IN2 제어, 100ms 브레이크 홀드 |
| `seven_seg_driver.v` | 4자리 7세그먼트 표시 (거리값 / FFFF) |
| `uart_rx.v` | 라즈베리파이 UART 수신 |
| `top.xdc` | 핀 제약 파일 (Basys3) |
| `camera_classify.py` | 카메라 색상분류 파이썬 코드 |

## 개발 중 주요 이슈

- **I2C NACK 문제**: 실보드 테스트 초반 VL53L0X에서 계속 NACK 발생. 배선·전원 문제로 의심했으나 실제 원인은 마스터 FSM의 ACK 샘플링 타이밍이 반 클럭 어긋난 것 — SCL/SDA 위상 조정으로 해결.
- **레지스터 포인터 소실**: 버튼 3번으로 나눠 STOP까지 끊는 방식이라 read 단계에서 VL53L0X가 레지스터 포인터를 잃는 문제 발생 → Repeated START를 지원하는 `i2c_master_v2` 구조로 재설계, 버튼 1번으로 전체 시퀀스 자동 수행하도록 변경.
- **UART 오작동**: 손 없이도 저절로 정지가 걸리는 노이즈 문제 → GND 재배선, 모터 전원단 디커플링 커패시터 추가, STOP 비트 검증 로직 추가로 해결.

## 개발/시뮬레이션 환경

- Xilinx Vivado (합성/구현, xc7a35tcpg236-1)
- Icarus Verilog(iverilog) + GTKWave — 초기 로직/타이밍 시뮬레이션 검증
