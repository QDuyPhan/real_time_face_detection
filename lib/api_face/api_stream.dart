import 'dart:async';
import 'dart:typed_data';

import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:signalr_netcore/itransport.dart';
import 'package:signalr_netcore/msgpack_hub_protocol.dart';

// Class chứa thông tin tạo khuôn mặt
class ItemCreateFaceSR {
  String name; // Tên người dùng
  String phone; // Số điện thoại
  Uint8List image; // Ảnh khuôn mặt

  ItemCreateFaceSR(this.name, this.phone, this.image);
}

// Class chứa thông tin chỉnh sửa khuôn mặt
class ItemEditFaceSR {
  String code; // Mã người dùng
  String name; // Tên người dùng
  String phone; // Số điện thoại

  ItemEditFaceSR(this.code, this.name, this.phone);
}

// Class chứa thông tin nhận diện khuôn mặt
class ItemDetectFaceSR {
  String id; // ID khuôn mặt
  Uint8List image; // Ảnh khuôn mặt

  ItemDetectFaceSR(this.id, this.image);
}

// Class chứa kết quả nhận diện khuôn mặt
class ItemResultDetectFaceSR {
  String id = ""; // ID người dùng
  String name = ""; // Tên người dùng
  String phone = ""; // Số điện thoại
}

// Class quản lý kết nối SignalR
class APIStream {
  late String _url; // URL server
  // Cấu hình kết nối HTTP
  final HttpConnectionOptions _httpOptions = HttpConnectionOptions(
      transport: HttpTransportType.WebSockets,
      skipNegotiation: true,
      logMessageContent: true,
      requestTimeout: 2000);

  // Stream controller cho data, state và face detection
  StreamController streamDataController = StreamController.broadcast();
  StreamController streamStateController = StreamController.broadcast();
  StreamController streamFaceController = StreamController.broadcast();

  HubConnection? _hubConnection; // Kết nối SignalR
  bool _isOpen = false; // Trạng thái kết nối

  // Constructor
  APIStream(String url) {
    _url = url;
  }

  // Khởi tạo kết nối SignalR
  Future<void> init() async {
    ///Nếu đã có kết nối trước đó, dừng nó để tránh xung đột trước khi khởi tạo lại.
    if (_hubConnection != null) {
      await _hubConnection!.stop();
    }

    // Cấu hình thời gian retry
    ///Tạo danh sách thời gian chờ giữa các lần thử kết nối lại.
    List<int> timeDelays = [];

    ///Tạo danh sách với 100 giá trị, tăng dần từ 1000ms (1 giây) đến 100000ms (100 giây).
    ///Điều này được sử dụng cho cơ chế tự động kết nối lại.
    for (int i = 0; i < 100; i++) {
      timeDelays.add(1000 * (i + 1));
    }

    // Khởi tạo kết nối SignalR
    _hubConnection = HubConnectionBuilder()
        .withUrl(_url, options: _httpOptions)
        .withHubProtocol(MessagePackHubProtocol())
        .withAutomaticReconnect(retryDelays: timeDelays)
        .build();

    // Cấu hình keep alive và timeout
    ///Gửi tín hiệu giữ kết nối mỗi 5 giây.
    _hubConnection?.keepAliveIntervalInMilliseconds = 5000;

    ///Đặt thời gian chờ server là 10 giây trước khi coi là mất kết nối.
    _hubConnection?.serverTimeoutInMilliseconds = 10000;

    // Xử lý sự kiện đóng kết nối
    _hubConnection?.onclose(({error}) {
      print("MySignalR Face closed");
      _isOpen = false;
      streamStateController.sink.add('offline');
    });

    // Xử lý sự kiện kết nối lại
    _hubConnection?.onreconnecting(({error}) {
      print("MySignalR Face reconnecting");
      _isOpen = false;
      streamStateController.sink.add('offline');
    });

    // Xử lý sự kiện kết nối thành công
    _hubConnection?.onreconnected(({connectionId}) {
      print("MySignalR Face reconnected");
      _isOpen = true;
      streamStateController.sink.add('online');
    });

    // Xử lý sự kiện tạo khuôn mặt
    _hubConnection?.on('CreateFace', (arguments) {
      // Xử lý tạo khuôn mặt
    });

    // Xử lý sự kiện chỉnh sửa người dùng
    _hubConnection?.on('EditPerson', (arguments) {
      // Xử lý chỉnh sửa người dùng
    });

    // Xử lý sự kiện nhận diện người dùng
    _hubConnection?.on('DetectPerson', (arguments) {
      if (arguments != null && arguments.length == 4) {
        String id = arguments[0] != null ? arguments[0].toString() : "";
        String code = arguments[1] != null ? arguments[1].toString() : "";
        String name = arguments[2] != null ? arguments[2].toString() : "";
        String phone = arguments[3] != null ? arguments[3].toString() : "";
        streamFaceController.sink.add([id, code, name, phone]);
      }
    });

    // Bắt đầu kết nối
    if (_hubConnection?.state != HubConnectionState.Connected) {
      await _hubConnection?.start();
      _isOpen = true;
      streamStateController.sink.add('online');
    }
  }

  // Tạo khuôn mặt mới
  bool createFace(String name, String phone, Uint8List image) {
    if (_hubConnection == null || _isOpen == false) {
      return false;
    }
    _hubConnection!.invoke('CreateFace', args: [name, phone, image]);
    return true;
  }

  // Chỉnh sửa thông tin người dùng
  bool editFace(String code, String name, String phone) {
    if (_hubConnection == null || _isOpen == false) {
      return false;
    }
    _hubConnection!
        .invoke('EditPerson', args: [ItemEditFaceSR(code, name, phone)]);
    return true;
  }

  // Nhận diện khuôn mặt
  bool detectFace(String id, Uint8List image) {
    if (_hubConnection == null || _isOpen == false) {
      return false;
    }
    _hubConnection!.invoke('DetectPerson', args: [id, image]);
    return true;
  }
}
