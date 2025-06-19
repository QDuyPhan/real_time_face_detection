# Real-Time Face Detection

Ứng dụng Flutter với khả năng nhận diện khuôn mặt thời gian thực sử dụng Google ML Kit.

## Tính năng

### 1. Basic Face Detection

- Phát hiện khuôn mặt đơn giản với bounding boxes
- Hiển thị thông tin cơ bản về khuôn mặt
- Chế độ camera trực tiếp và gallery

### 2. Advanced Face Detection (Mới)

- **Real-time tracking**: Theo dõi khuôn mặt qua nhiều frame
- **Face registration**: Đăng ký khuôn mặt mới với thông tin cá nhân
- **Face identification**: Nhận diện khuôn mặt đã đăng ký
- **Multi-face tracking**: Theo dõi nhiều khuôn mặt cùng lúc
- **Angle detection**: Phát hiện góc nghiêng của khuôn mặt
- **Image cropping**: Tự động cắt ảnh khuôn mặt với chất lượng cao
- **Background processing**: Xử lý ảnh trên isolate riêng để tối ưu hiệu suất

## Cấu trúc Logic Nhận Diện Nâng Cao

### API Camera (`api_camera.dart`)

- Quản lý camera và stream ảnh
- Xử lý ảnh trên background isolate
- Chuyển đổi định dạng ảnh (YUV420 → NV21 → RGB)
- Tối ưu hóa hiệu suất với multi-threading

### API Face (`api_face.dart`)

- Quản lý danh sách khuôn mặt được theo dõi
- Tracking khuôn mặt qua tracking ID
- Lọc khuôn mặt dựa trên góc nghiêng
- Cắt ảnh khuôn mặt tự động
- Quản lý thời gian và lifecycle của khuôn mặt

### InfoPerson Class

```dart
class InfoPerson {
  String id = "";           // ID người dùng
  String name = "";         // Tên người dùng
  String phone = "";        // Số điện thoại
  String faceId = "";       // ID khuôn mặt (tracking ID)
  double angleX = 0;        // Góc nghiêng X
  double angleY = 0;        // Góc nghiêng Y
  double angleZ = 0;        // Góc nghiêng Z
  double x = 0, y = 0;      // Tọa độ trung tâm
  double w = 0, h = 0;      // Kích thước khuôn mặt
  Uint8List image;          // Ảnh khuôn mặt đã cắt
  bool busy = false;        // Trạng thái xử lý
  bool check = false;       // Cần gửi yêu cầu nhận diện
}
```

## Cách Sử Dụng

### 1. Khởi chạy ứng dụng

```bash
flutter pub get
flutter run
```

### 2. Chọn chế độ nhận diện

- **Basic Face Detector**: Nhận diện đơn giản
- **Advanced Face Detection**: Nhận diện nâng cao với tracking

### 3. Sử dụng Advanced Face Detection

1. Nhấn "Start" để bắt đầu nhận diện
2. Đặt khuôn mặt trong khung camera
3. Hệ thống sẽ tự động:
   - Phát hiện và track khuôn mặt
   - Cắt ảnh khi khuôn mặt thẳng (góc < 45°)
   - Hiển thị thông tin chi tiết
4. Sử dụng nút "Register" hoặc "Identify" để đăng ký/nhận diện

## Cấu hình

### Camera Settings

- Resolution: `ResolutionPreset.low` (tối ưu hiệu suất)
- Format: `ImageFormatGroup.nv21`
- Audio: Disabled

### Face Detection Settings

```dart
FaceDetectorOptions(
  enableContours: true,      // Phát hiện đường viền
  enableClassification: true, // Phân loại cảm xúc
  enableTracking: true,      // Tracking khuôn mặt
  performanceMode: FaceDetectorMode.accurate, // Chế độ chính xác
)
```

### Tracking Parameters

- **Time threshold**: 1000ms (1 giây) để loại bỏ khuôn mặt cũ
- **Angle threshold**: 45° để lọc khuôn mặt thẳng
- **Request interval**: 2000ms (2 giây) giữa các yêu cầu nhận diện
- **Crop margins**: 60% width, 75-85% height

## Tối ưu hóa Hiệu suất

1. **Background Processing**: Xử lý ảnh trên isolate riêng
2. **Image Format**: Sử dụng NV21 format cho Android
3. **Resolution**: Giảm độ phân giải để tăng tốc độ
4. **Memory Management**: Tự động dọn dẹp khuôn mặt cũ
5. **Stream Management**: Sử dụng StreamController để cập nhật UI

## Dependencies

```yaml
dependencies:
  camera: ^0.10.5+9
  google_mlkit_face_detection: ^0.9.0
  image: ^4.0.17
  permission_handler: ^12.0.0+1
```

## Lưu ý

- Cần cấp quyền camera khi chạy ứng dụng
- Logic nâng cao hoạt động tốt nhất với khuôn mặt thẳng
- Hệ thống tự động quản lý memory và performance
- Có thể mở rộng để tích hợp với server API cho nhận diện từ xa

## Tương lai

- [ ] Tích hợp API server cho nhận diện từ xa
- [ ] Lưu trữ local database cho khuôn mặt đã đăng ký
- [ ] Cải thiện accuracy với deep learning models
- [ ] Thêm tính năng liveness detection
- [ ] Support cho multiple camera angles
