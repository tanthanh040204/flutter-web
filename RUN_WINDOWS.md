# Chạy app trên Windows (khuyên dùng)

## 1) Cài dependencies
```powershell
flutter pub get
```

## 2) Chạy Windows
```powershell
flutter run -d windows
```

Nếu Flutter hỏi chọn device, chọn **Windows**.

## 3) Nếu bạn đã cấu hình Firebase (flutterfire configure) trong project này:
- File `lib/firebase_options.dart` phải là file thật (không phải placeholder)
- Android/web configs không ảnh hưởng đến Windows
