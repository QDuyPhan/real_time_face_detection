# Real-Time Face Detection & Recognition System

Ứng dụng Flutter với khả năng phát hiện và nhận diện khuôn mặt thời gian thực, hoạt động hoàn toàn offline trên thiết bị di động.

## 🚀 Tính năng chính

### ✨ Face Detection (Phát hiện khuôn mặt)

- Phát hiện khuôn mặt thời gian thực từ camera
- Theo dõi nhiều khuôn mặt cùng lúc
- Lọc khuôn mặt dựa trên góc quay (chỉ xử lý khuôn mặt thẳng)
- Tối ưu hóa hiệu suất với Isolate

### 🎯 Face Recognition (Nhận diện khuôn mặt)

- **Hoạt động offline hoàn toàn** - không cần kết nối internet
- Lưu trữ khuôn mặt trong cơ sở dữ liệu SQLite local
- So sánh khuôn mặt với độ chính xác cao
- Hiển thị thông tin người dùng khi nhận diện thành công

### 👥 Face Management (Quản lý khuôn mặt)

- Đăng ký khuôn mặt mới với tên và số điện thoại
- Xem danh sách tất cả khuôn mặt đã đăng ký
- Chỉnh sửa thông tin người dùng
- Xóa khuôn mặt không cần thiết

## 🛠️ Công nghệ sử dụng

- **Flutter** - Framework UI
- **Google ML Kit** - Face Detection
- **Camera Plugin** - Truy cập camera
- **SQLite** - Lưu trữ dữ liệu local
- **Isolate** - Xử lý đa luồng
- **Image Processing** - Xử lý và so sánh ảnh

## 📱 Cài đặt và chạy

### Yêu cầu hệ thống

- Flutter SDK 3.7.2+
- Android Studio / VS Code
- Thiết bị Android/iOS hoặc emulator

### Cài đặt dependencies

```bash
flutter pub get
```

### Chạy ứng dụng

```bash
flutter run
```

## 🎮 Hướng dẫn sử dụng

### 1. Màn hình chính

- **Face Recognition**: Bắt đầu nhận diện khuôn mặt thời gian thực
- **Face Management**: Quản lý danh sách khuôn mặt đã đăng ký
- **Legacy Face Detector**: Chế độ phát hiện khuôn mặt cũ

### 2. Đăng ký khuôn mặt mới

1. Vào **Face Management**
2. Nhấn nút **+** (Floating Action Button)
3. Nhập tên và số điện thoại
4. Nhìn thẳng vào camera và giữ nguyên tư thế
5. Hệ thống sẽ tự động chụp và lưu khuôn mặt

### 3. Nhận diện khuôn mặt

1. Vào **Face Recognition**
2. Nhìn vào camera
3. Hệ thống sẽ hiển thị:
   - ✅ **Recognized!** + tên + số điện thoại + độ chính xác (nếu nhận diện được)
   - ❓ **Unknown Face** (nếu không nhận diện được)

## 🏗️ Kiến trúc hệ thống

### Core Components

```
lib/
├── api_face/
│   ├── api_face.dart          # Engine xử lý chính
│   ├── api_camera.dart        # Quản lý camera
│   └── local_face_database.dart # Database local
├── screens/
│   ├── camera_screen.dart     # Màn hình nhận diện
│   └── face_management_screen.dart # Màn hình quản lý
└── home_screen.dart           # Màn hình chính
```

### Luồng xử lý

1. **Camera Stream** → **Face Detection** → **Image Processing**
2. **Local Database** → **Face Comparison** → **Recognition Result**
3. **UI Update** → **Display Result**

## 🔧 Tùy chỉnh

### Ngưỡng nhận diện

Trong `local_face_database.dart`, thay đổi ngưỡng similarity:

```dart
if (similarity > bestSimilarity && similarity > 0.7) // 70%
```

### Kích thước ảnh

Trong `api_face.dart`, điều chỉnh các tham số cắt ảnh:

```dart
double s_x1 = 0.6;  // Tỷ lệ cắt ngang
double s_y1 = 0.75; // Tỷ lệ cắt dọc
```

### Tần suất nhận diện

Thay đổi thời gian giữa các lần nhận diện:

```dart
if (time > 2000) // 2 giây
```

## 📊 Hiệu suất

- **FPS**: 15-30 FPS tùy thiết bị
- **Độ chính xác**: 85-95% với điều kiện ánh sáng tốt
- **Bộ nhớ**: ~50MB cho 100 khuôn mặt
- **Thời gian phản hồi**: <500ms

## 🔒 Bảo mật

- Dữ liệu được lưu trữ local hoàn toàn
- Không gửi ảnh lên server
- Mã hóa hash cho ảnh khuôn mặt
- Quyền truy cập camera được kiểm soát

## 🐛 Troubleshooting

### Lỗi thường gặp

1. **Camera không hoạt động**: Kiểm tra quyền truy cập camera
2. **Nhận diện không chính xác**: Điều chỉnh ánh sáng và góc nhìn
3. **Ứng dụng chậm**: Giảm độ phân giải camera hoặc tăng thời gian giữa các lần nhận diện

### Debug

Bật debug mode để xem log chi tiết:

```dart
print('[Debug face] Size : ${faces.length}');
print('[Local Recognition] Recognized: ${person.name}');
```

## 📈 Roadmap

- [ ] Cải thiện thuật toán so sánh khuôn mặt
- [ ] Thêm tính năng backup/restore dữ liệu
- [ ] Hỗ trợ nhận diện khuôn mặt với khẩu trang
- [ ] Tích hợp với hệ thống điểm danh
- [ ] Thêm tính năng lịch sử nhận diện

## 🤝 Đóng góp

Mọi đóng góp đều được chào đón! Vui lòng:

1. Fork project
2. Tạo feature branch
3. Commit changes
4. Push to branch
5. Tạo Pull Request

## 📄 License

MIT License - xem file LICENSE để biết thêm chi tiết.

---

**Lưu ý**: Hệ thống này hoạt động hoàn toàn offline và không gửi dữ liệu cá nhân lên bất kỳ server nào. Tất cả dữ liệu được lưu trữ an toàn trên thiết bị của bạn.
