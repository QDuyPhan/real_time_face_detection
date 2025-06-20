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

          streamFaceController.sink.add([faces, img, size, rotation]);

          if (faces.length > 0) {
            for (int i = 0; i < faces.length; i++) {
              app_config.printLog(
                'i',
                '[Debug face] Info Face : $i - ${faces[i].trackingId}',
              );
              if (faces[i].trackingId != null) {
                if (persons.length > 0) {
                  bool flag = false;
                  for (int j = 0; j < persons.length; j++) {
                    if (persons[j].faceId.compareTo(
                          faces[i].trackingId!.toString(),
                        ) ==
                        0) {
                      persons[j].lastest =
                          DateTime.now().millisecondsSinceEpoch;

                      persons[j].angleX = faces[i].headEulerAngleX ?? 0;
                      persons[j].angleY = faces[i].headEulerAngleY ?? 0;
                      persons[j].angleZ = faces[i].headEulerAngleZ ?? 0;

                      persons[j].x = faces[i].boundingBox.center.dx;
                      persons[j].y = faces[i].boundingBox.center.dy;
                      persons[j].w = faces[i].boundingBox.width;
                      persons[j].h = faces[i].boundingBox.height;

                      if (persons[j].angleX.abs() < 45 &&
                          persons[j].angleY.abs() < 45 &&
                          persons[j].angleZ.abs() < 45) {
                        if (persons[j].busy == false) {
                          if (persons[j].phone.isEmpty) {
                            int x1 =
                                (persons[j].x - persons[j].w * cropX1).toInt();
                            int y1 =
                                (persons[j].y - persons[j].h * cropY1).toInt();
                            int x2 =
                                (persons[j].x + persons[j].w * cropX2).toInt();
                            int y2 =
                                (persons[j].y + persons[j].h * cropY2).toInt();

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

                            if (rotation == InputImageRotation.rotation90deg) {
                              buffer = imglib.copyRotate(buffer, angle: 90);
                            } else if (rotation ==
                                InputImageRotation.rotation180deg) {
                              buffer = imglib.copyRotate(buffer, angle: 180);
                            } else if (rotation ==
                                InputImageRotation.rotation270deg) {
                              buffer = imglib.copyRotate(buffer, angle: 270);
                            }

                            persons[j].image = Uint8List.fromList(
                              imglib.encodeJpg(buffer, quality: 90),
                            );

                            persons[j].busy = true;
                            persons[j].check = true;
                          }
                        }
                      }

                      flag = true;
                      break;
                    }
                  }

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
                      // Xoay lại buffer dựa trên rotation
                      if (rotation == InputImageRotation.rotation90deg) {
                        buffer = imglib.copyRotate(buffer, angle: 90);
                      } else if (rotation ==
                          InputImageRotation.rotation180deg) {
                        buffer = imglib.copyRotate(buffer, angle: 180);
                      } else if (rotation ==
                          InputImageRotation.rotation270deg) {
                        buffer = imglib.copyRotate(buffer, angle: 270);
                      }
                      info.image = Uint8List.fromList(
                        imglib.encodeJpg(buffer, quality: 90),
                      );
                      info.busy = true;
                      info.check = true;
                    }
                    persons.add(info);
                  }
                } else {
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
                    // Xoay lại buffer dựa trên rotation
                    if (rotation == InputImageRotation.rotation90deg) {
                      buffer = imglib.copyRotate(buffer, angle: 90);
                    } else if (rotation == InputImageRotation.rotation180deg) {
                      buffer = imglib.copyRotate(buffer, angle: 180);
                    } else if (rotation == InputImageRotation.rotation270deg) {
                      buffer = imglib.copyRotate(buffer, angle: 270);
                    }
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

          if (persons.length > 0) {
            int m_time = DateTime.now().millisecondsSinceEpoch;
            for (int i = 0; i < persons.length; i++) {
              int tmp = m_time - persons[i].lastest;
              if (tmp > 1000) {
                // persons.removeAt(i);
                persons.removeWhere((p) => DateTime.now().millisecondsSinceEpoch - p.lastest > 1000);
                i--;
              }
            }
          }

          app_config.printLog('i', '[Debug face] : length ${persons.length}');

          // Gửi danh sách persons cập nhật lên stream để UI có thể hiển thị
          streamPersonController.sink.add(List<InfoPerson>.from(persons));

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

                  persons[i].check = false;
                  persons[i].timecheck = DateTime.now().millisecondsSinceEpoch;
                }
              } else {
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

  Future<void> start() async {
    if (camera.state() == false) {
      persons.clear();
      await camera.start();
    }
  }

  void stop() {
    print('APIFace: stop() called');
    app_config.printLog('i', '[Debug face] : stop() called');
    if (camera.state() == true) {
      camera.stop();
      persons.clear();
      print('APIFace: stop() completed - camera stopped and persons cleared');
      app_config.printLog('i', '[Debug face] : stop() completed - camera stopped and persons cleared');
    } else {
      print('APIFace: stop() - camera was not running');
      app_config.printLog('i', '[Debug face] : stop() - camera was not running');
    }
  }

  bool state() {
    return camera.state();
  }

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

  bool createPerson(String faceid, String name, String phone) {
    if (persons.isNotEmpty) {
      for (int i = 0; i < persons.length; i++) {
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
