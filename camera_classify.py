import cv2
import numpy as np
import serial
import time

# 카메라 / UART 설정
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
ser = serial.Serial('/dev/ttyAMA0', 19200, timeout=1)

# 피부색 HSV 범위
SKIN_LOWER = np.array([0, 10, 10], dtype=np.uint8)
SKIN_UPPER = np.array([30, 255, 255], dtype=np.uint8)

# 감지 기준 (히스테리시스: 켜짐/꺼짐 임계값 다르게)
UPPER_THRESHOLD = 3000
LOWER_THRESHOLD = 2000

high_count = 0
low_count = 0
person_detected = False

while True:
    ret, frame = cap.read()
    if not ret:
        break

    h, w = frame.shape[:2]
    # ROI: 화면의 20%~62% 구간만 (벨트 영역)
    roi = frame[:, int(w * 0.20):int(w * 0.62)]

    # 피부색 마스크 추출 + 노이즈 제거
    hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, SKIN_LOWER, SKIN_UPPER)
    mask = cv2.erode(mask, None, iterations=1)
    mask = cv2.dilate(mask, None, iterations=1)
    pixels = np.count_nonzero(mask)

    if not person_detected:
        # 2번 연속 감지
        if pixels > UPPER_THRESHOLD:
            high_count += 1
        else:
            high_count = 0

        if high_count >= 2:
            person_detected = True
            high_count = 0
            print(f"사람 감지! pixels = {pixels}")
            # UART 노이즈 대비 A5 5회 반복 전송
            for i in range(5):
                ser.write(bytes([0xA5]))
                print(f"A5 전송 {i+1}/5")
                time.sleep(0.05)
    else:
        # 5번 연속 미감지
        if pixels < LOWER_THRESHOLD:
            low_count += 1
        else:
            low_count = 0

        if low_count >= 5:
            person_detected = False
            low_count = 0
            ser.write(bytes([0x00]))
            print(f"사람 없음! pixels = {pixels}")
            print("00 전송")

    print(f"pixels = {pixels}, detected = {person_detected}")
    time.sleep(0.05)

cap.release()
ser.close()
