# EV App + Firebase (Firestore) - Trọn gói

## BẮT BUỘC (Firebase config phụ thuộc project của bạn)
Trong thư mục project (cùng pubspec.yaml), chạy:

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
$env:Path += ";C:\Users\Asus\AppData\Local\Pub\Cache\bin"
flutterfire configure
```

## Chạy app
```powershell
flutter pub get
flutter run
```

## Test ghi dữ liệu
- Bấm "Giả lập +1km" hoặc "Giảm pin 5%" -> Firestore sẽ có/đổi doc `vehicles/{vehicleId}`
- Trong "Bảo dưỡng" bấm "Đã thay/đã làm" -> subcollection `vehicles/{vehicleId}/maintenance` update
