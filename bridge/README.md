# MQTT → Firestore Bridge

## Mục tiêu
- Subscribe dữ liệu realtime từ HiveMQ
- Ghi trạng thái mới nhất của xe vào Firestore

## Topic mặc định
vehicles/+/state

## Payload ví dụ
```json

 {
  "id": "xe1",
  "temp": 31.5,
  "hum": 67.2,
  "dust": 42.8,
  "batteryPercent": 83,
  "isLocked": true,
  "isRunning": false,
  "totalKm": 1.2,
  "lat": 21.0287,
  "lon": 105.8522
}