import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

import 'api_camera.dart';
import 'app_config.dart';

class InfoPerson {
  String id = "";
  String name = "";
  String phone = "";
  String faceId = "";
  double angleX = 0;
  double angleY = 0;
  double angleZ = 0;
  double x = 0;
  double y = 0;
  double w = 0;
  double h = 0;

  Uint8List image = Uint8List(0);
  int lastest = DateTime.now().millisecondsSinceEpoch;
  int timecheck = 1;
  bool busy = false;
  bool check = false;

  void update(InfoPerson other) {
    id = other.id;
    name = other.name;
    phone = other.phone;
    faceId = other.faceId;
    angleX = other.angleX;
    angleY = other.angleY;
    angleZ = other.angleZ;
    x = other.x;
    y = other.y;
    w = other.w;
    h = other.h;
    image = other.image;
    lastest = DateTime.now().millisecondsSinceEpoch;
    timecheck = other.timecheck;
    busy = other.busy;
    check = other.check;
  }

  // Map<String, dynamic> toJson() => {
  //   'id': id,
  //   'name': name,
  //   'phone': phone,
  //   'faceId': faceId,
  //   'angleX': angleX,
  //   'angleY': angleY,
  //   'angleZ': angleZ,
  //   'x': x,
  //   'y': y,
  //   'w': w,
  //   'h': h,
  //   'image': base64Encode(image), // Chuyển byte thành base64
  //   'lastest': lastest,
  //   'timecheck': timecheck,
  //   'busy': busy,
  //   'check': check,
  // };

  // factory InfoPerson.fromJson(Map<String, dynamic> json) => InfoPerson(
  //   id: json['id'] ?? "",
  //   name: json['name'] ?? "",
  //   phone: json['phone'] ?? "",
  //   faceId: json['faceId'] ?? "",
  //   angleX: (json['angleX'] ?? 0).toDouble(),
  //   angleY: (json['angleY'] ?? 0).toDouble(),
  //   angleZ: (json['angleZ'] ?? 0).toDouble(),
  //   x: (json['x'] ?? 0).toDouble(),
  //   y: (json['y'] ?? 0).toDouble(),
  //   w: (json['w'] ?? 0).toDouble(),
  //   h: (json['h'] ?? 0).toDouble(),
  //   image: json['image'] != null ? base64Decode(json['image']) : Uint8List(0),
  //   lastest: json['lastest'] ?? 0,
  //   timecheck: json['timecheck'] ?? 1,
  //   busy: json['busy'] ?? false,
  //   check: json['check'] ?? false,
  // );
}

class APIFace {
  List<InfoPerson> persons = [];

  double cropX1 = 0.6;
  double cropX2 = 0.6;
  double cropY1 = 0.75;
  double cropY2 = 0.85;

  late APICamera camera;

  StreamController streamFaceController = StreamController.broadcast();
  StreamController streamPersonController = StreamController.broadcast();
  StreamController streamFacesForUI = StreamController.broadcast();

  APIFace() {
    camera = APICamera(CameraLensDirection.front);
  }

  void init(RootIsolateToken rootIsolateToken) {
    camera.init(rootIsolateToken);

    ///Mã này lọc khuôn mặt dựa trên góc quay, cắt ảnh theo ngưỡng,
    /// cập nhật hoặc thêm vào persons, quản lý thời gian, và gửi yêu cầu nhận diện khi cần.
    /// Các điều kiện đảm bảo xử lý an toàn, tránh lỗi và tối ưu hóa hiệu suất.
    camera.streamDectectFaceController.stream.listen((event) {
      if (event is List && event.length == 4) {
        if (event[0] is List<Face> &&
            event[1] is imglib.Image &&
            event[2] is Size &&
            event[3] is InputImageRotation) {
          List<Face> faces = event[0];
          imglib.Image img = event[1];
          Size size = event[2];
          InputImageRotation rotation = event[3];
          app_config.printLog('i', '[Debug face] Size : ${faces.length}');

          // Gửi thông tin faces lên stream để UI có thể hiển thị (bounding box)
          streamFaceController.sink.add([faces, img, size, rotation]);

          ///Xử lý khi có khuôn mặt
          if (faces.length > 0) {
            for (int i = 0; i < faces.length; i++) {
              app_config.printLog(
                'i',
                '[Debug face] Info Face : $i - ${faces[i].trackingId}',
              );
              if (faces[i].trackingId != null) {
                ///Kiểm tra và cập nhật danh sách persons
                ///Kiểm tra xem danh sách persons (danh sách các InfoPerson đã theo dõi) có phần tử nào không.
                /// Nếu rỗng, nhảy thẳng đến khối xử lý thêm mới.
                if (persons.length > 0) {
                  ///Khởi tạo biến flag là false.
                  ///Biến này sẽ được đặt thành true nếu tìm thấy khuôn mặt hiện tại trong persons,
                  /// dùng để quyết định có thêm mới hay không.
                  bool flag = false;
                  for (int j = 0; j < persons.length; j++) {
                    ///So sánh faceId của persons[j] (ID khuôn mặt đã lưu)
                    ///với trackingId của khuôn mặt hiện tại (chuyển thành chuỗi).
                    /// compareTo trả về 0 nếu hai chuỗi bằng nhau,
                    /// chỉ ra rằng đây là cùng một khuôn mặt đã được theo dõi.
                    if (persons[j].faceId.compareTo(
                          faces[i].trackingId!.toString(),
                        ) ==
                        0) {
                      persons[j].lastest =
                          DateTime.now().millisecondsSinceEpoch;

                      ///Gán giá trị góc quay (headEulerAngleX, headEulerAngleY, headEulerAngleZ)
                      ///từ Face vào angleX, angleY, angleZ.
                      /// ?? 90: Nếu giá trị là null (không đo được),
                      /// đặt mặc định là 90 độ (có thể không hợp lý, nên xem xét thay bằng 0).
                      persons[j].angleX = faces[i].headEulerAngleX ?? 0;
                      persons[j].angleY = faces[i].headEulerAngleY ?? 0;
                      persons[j].angleZ = faces[i].headEulerAngleZ ?? 0;

                      ///Cập nhật tọa độ trung tâm (center.dx, center.dy) và
                      ///kích thước (width, height) của vùng khuôn mặt từ boundingBox vào x, y, w, h.
                      persons[j].x = faces[i].boundingBox.center.dx;
                      persons[j].y = faces[i].boundingBox.center.dy;
                      persons[j].w = faces[i].boundingBox.width;
                      persons[j].h = faces[i].boundingBox.height;

                      ///Kiểm tra xem góc quay tuyệt đối của khuôn mặt có nhỏ hơn 45 độ không
                      ///(tức là khuôn mặt gần thẳng, không nghiêng quá nhiều).
                      /// && yêu cầu cả ba góc (angleX, angleY, angleZ) đều thỏa mãn để tiếp tục.
                      if (persons[j].angleX.abs() < 45 &&
                          persons[j].angleY.abs() < 45 &&
                          persons[j].angleZ.abs() < 45) {
                        ///Kiểm tra xem busy (trạng thái xử lý) có là false không,
                        ///đảm bảo không trùng lặp xử lý cùng một khuôn mặt.
                        if (persons[j].busy == false) {
                          ///Kiểm tra xem phone có rỗng không,
                          ///chỉ xử lý nếu thông tin người chưa được nhận diện (chưa có số điện thoại từ server).
                          if (persons[j].phone.isEmpty) {
                            ///Tính toán tọa độ vùng cắt ảnh:
                            /// x1, y1: Góc trên bên trái, dựa trên ngưỡng cropX1 (0.6) và cropY1 (0.75) để thu hẹp vùng.
                            /// x2, y2: Góc dưới bên phải, dựa trên ngưỡng cropX2 (0.6) và cropY2 (0.85) để mở rộng vùng.
                            int x1 =
                                (persons[j].x - persons[j].w * cropX1).toInt();
                            int y1 =
                                (persons[j].y - persons[j].h * cropY1).toInt();
                            int x2 =
                                (persons[j].x + persons[j].w * cropX2).toInt();
                            int y2 =
                                (persons[j].y + persons[j].h * cropY2).toInt();

                            ///Điều chỉnh tọa độ để nằm trong giới hạn ảnh:
                            /// Nếu x1 hoặc y1 < 0, đặt về 0.
                            /// Nếu x2 > chiều rộng ảnh - 1 hoặc y2 > chiều cao ảnh - 1, giới hạn về giá trị tối đa.
                            if (x1 < 0) {
                              x1 = 0;
                            }
                            if (y1 < 0) {
                              y1 = 0;
                            }
                            if (x2 > (img.width - 1)) {
                              x2 = img.width - 1;
                            }
                            if (y2 > (img.height - 1)) {
                              y2 = img.height - 1;
                            }

                            ///Cắt một vùng ảnh từ img dựa trên tọa độ đã tính, lưu vào buffer.
                            imglib.Image buffer = imglib.copyCrop(
                              img,
                              x: x1,
                              y: y1,
                              width: x2 - x1,
                              height: y2 - y1,
                            );

                            ///Nén buffer thành JPEG với chất lượng 90 và chuyển thành Uint8List,
                            /// gán vào image của persons[j].
                            persons[j].image = Uint8List.fromList(
                              imglib.encodeJpg(buffer, quality: 90),
                            );

                            ///Đặt busy = true để đánh dấu đang xử lý,
                            ///check = true để báo hiệu cần gửi yêu cầu nhận diện.
                            persons[j].busy = true;
                            persons[j].check = true;
                          }
                        }
                      }

                      ///Đặt flag = true khi tìm thấy khớp, và break để thoát vòng lặp, tránh xử lý trùng lặp.
                      flag = true;
                      break;
                    }
                  }

                  /// Kết thúc vòng for
                  /// Xử lý khi không tìm thấy trong persons
                  /// Nếu flag vẫn là false sau vòng lặp,
                  /// nghĩa là không tìm thấy khuôn mặt trong persons, tiến hành thêm mới.
                  if (flag == false) {
                    app_config.printLog(
                      'i',
                      '[Debug face] Add : ${faces[i].trackingId!.toString()}',
                    );
                    InfoPerson info = InfoPerson();
                    info.faceId = faces[i].trackingId!.toString();
                    info.lastest = DateTime.now().millisecondsSinceEpoch;

                    info.angleX = faces[i].headEulerAngleX ?? 0;
                    info.angleY = faces[i].headEulerAngleY ?? 0;
                    info.angleZ = faces[i].headEulerAngleZ ?? 0;

                    info.x = faces[i].boundingBox.center.dx;
                    info.y = faces[i].boundingBox.center.dy;
                    info.w = faces[i].boundingBox.width;
                    info.h = faces[i].boundingBox.height;

                    if (info.angleX.abs() < 45 &&
                        info.angleY.abs() < 45 &&
                        info.angleZ.abs() < 45) {
                      int x1 = (info.x - info.w * cropX1).toInt();
                      int y1 = (info.y - info.h * cropY1).toInt();
                      int x2 = (info.x + info.w * cropX2).toInt();
                      int y2 = (info.y + info.h * cropY2).toInt();

                      if (x1 < 0) {
                        x1 = 0;
                      }
                      if (y1 < 0) {
                        y1 = 0;
                      }
                      if (x2 > (img.width - 1)) {
                        x2 = img.width - 1;
                      }
                      if (y2 > (img.height - 1)) {
                        y2 = img.height - 1;
                      }
                      imglib.Image buffer = imglib.copyCrop(
                        img,
                        x: x1,
                        y: y1,
                        width: x2 - x1,
                        height: y2 - y1,
                      );
                      info.image = Uint8List.fromList(
                        imglib.encodeJpg(buffer, quality: 90),
                      );
                      info.busy = true;
                      info.check = true;
                    }
                    persons.add(info);
                  }
                }
                ///Nếu persons.length == 0,
                /// thực hiện khối này để thêm mới InfoPerson trực tiếp (tương tự flag == false).
                else {
                  app_config.printLog(
                    'i',
                    '[Debug face] Add : ${faces[i].trackingId!.toString()}',
                  );
                  InfoPerson info = InfoPerson();
                  info.faceId = faces[i].trackingId!.toString();
                  info.lastest = DateTime.now().millisecondsSinceEpoch;
                  info.angleX = faces[i].headEulerAngleX ?? 0;
                  info.angleY = faces[i].headEulerAngleY ?? 0;
                  info.angleZ = faces[i].headEulerAngleZ ?? 0;
                  info.x = faces[i].boundingBox.center.dx;
                  info.y = faces[i].boundingBox.center.dy;
                  info.w = faces[i].boundingBox.width;
                  info.h = faces[i].boundingBox.height;

                  if (info.angleX.abs() < 45 &&
                      info.angleY.abs() < 45 &&
                      info.angleZ.abs() < 45) {
                    int x1 = (info.x - info.w * cropX1).toInt();
                    int y1 = (info.y - info.h * cropY1).toInt();
                    int x2 = (info.x + info.w * cropX2).toInt();
                    int y2 = (info.y + info.h * cropY2).toInt();

                    if (x1 < 0) {
                      x1 = 0;
                    }
                    if (y1 < 0) {
                      y1 = 0;
                    }
                    if (x2 > (img.width - 1)) {
                      x2 = img.width - 1;
                    }
                    if (y2 > (img.height - 1)) {
                      y2 = img.height - 1;
                    }
                    imglib.Image buffer = imglib.copyCrop(
                      img,
                      x: x1,
                      y: y1,
                      width: x2 - x1,
                      height: y2 - y1,
                    );
                    info.image = Uint8List.fromList(
                      imglib.encodeJpg(buffer, quality: 90),
                    );
                    info.busy = true;
                    info.check = true;
                  }
                  persons.add(info);
                }
              }
            }
          }

          ///Quản lý thời gian và loại bỏ
          ///Lấy thời gian hiện tại (m_time).
          /// Duyệt persons, nếu chênh lệch thời gian với lastest > 1000ms (1 giây),
          /// xóa phần tử và giảm i để tránh bỏ sót.
          if (persons.length > 0) {
            int m_time = DateTime.now().millisecondsSinceEpoch;
            for (int i = 0; i < persons.length; i++) {
              int tmp = m_time - persons[i].lastest;
              if (tmp > 1000) {
                persons.removeAt(i);
                i--;
              }
            }
          }

          app_config.printLog('i', '[Debug face] : length ${persons.length}');

          // Gửi danh sách persons cập nhật lên stream để UI có thể hiển thị
          streamPersonController.sink.add(List<InfoPerson>.from(persons));

          ///Gửi yêu cầu nhận diện
          ///Kiểm tra check == true (cần gửi yêu cầu).
          /// Nếu thời gian từ timecheck > 2000ms (2 giây), gửi yêu cầu.
          if (persons.isNotEmpty) {
            app_config.printLog(
              'i',
              '[Debug face] : * length ${persons.length}',
            );
            for (int i = 0; i < persons.length; i++) {
              if (persons[i].check == true) {
                int time =
                    DateTime.now().millisecondsSinceEpoch -
                    persons[i].timecheck;
                if (time > 2000) {
                  app_config.printLog(
                    'i',
                    '[Debug face] : request detect face ${i} : ${persons[i].faceId}',
                  );
                  app_config.printLog(
                    'i',
                    '[Face] : ${persons[i].id} | ${persons[i].faceId} - ${persons[i].lastest} | ${persons[i].angleX} , ${persons[i].angleY} , ${persons[i].angleZ} - ${persons[i].image.length} - ${persons[i].w} x ${persons[i].h}',
                  );

                  ///Gửi faceId và image lên server qua APIStream.

                  ///Đặt check = false sau khi gửi, cập nhật timecheck.
                  persons[i].check = false;
                  persons[i].timecheck = DateTime.now().millisecondsSinceEpoch;
                }
              } else {
                ///Nếu time <= 2000ms, in debug rằng không gửi yêu cầu, hiển thị faceId và phone (nếu có).
                app_config.printLog(
                  'i',
                  '[Debug face] : dont request detect face ${i} : ${persons[i].faceId} : ${persons[i].phone}',
                );
              }
            }
          }
        }
      }
    });
  }

  ///Khởi động camera: Đảm bảo camera được bật để thu nhận dữ liệu hình ảnh.
  /// Làm sạch dữ liệu: Xóa danh sách persons khi camera khởi động lại, tránh nhầm lẫn với dữ liệu từ lần chạy trước.
  /// Quản lý trạng thái: Chỉ thực hiện khi camera chưa chạy, tránh khởi động lại không cần thiết.
  Future<void> start() async {
    if (camera.state() == false) {
      persons.clear();
      await camera.start();
    }
  }

  void stop() {
    if (camera.state() == true) {
      camera.stop();
      persons.clear();
    }
  }

  bool state() {
    return camera.state();
  }

  ///Tìm và trả về thông tin của người có khuôn mặt lớn nhất (dựa trên w - chiều rộng) trong danh sách persons.
  ///Xác định người nổi bật nhất (dựa trên kích thước khuôn mặt) để ưu tiên hiển thị hoặc xử lý.
  List<String> findPerson() {
    if (persons.isNotEmpty) {
      int index = 0;
      double max = 0;
      for (int i = 0; i < persons.length; i++) {
        if (max < persons[i].w) {
          index = i;
          max = persons[i].w;
        }
      }
      List<String> result = [];
      result.add(persons[index].faceId);
      result.add(persons[index].id);
      result.add(persons[index].name);
      result.add(persons[index].phone);
      return result;
    } else {
      return [];
    }
  }

  ///Tạo một bản ghi khuôn mặt mới trên server bằng cách gửi thông tin (name, phone) và ảnh (image) nếu tìm thấy faceId khớp.
  ///Đăng ký thông tin người dùng cho một khuôn mặt đã được phát hiện.
  bool createPerson(String faceid, String name, String phone) {
    if (persons.isNotEmpty) {
      for (int i = 0; i < persons.length; i++) {
        ///So sánh faceId của phần tử hiện tại với faceid được truyền vào. Nếu bằng nhau, tìm thấy khớp.
        if (persons[i].faceId.compareTo(faceid) == 0) {
          if (persons[i].image.isNotEmpty) {
            return true;
          } else {
            return false;
          }
        }
      }
      return false;
    } else {
      return false;
    }
  }
}
