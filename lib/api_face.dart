import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

import 'api_camera.dart';

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
    this.id = other.id;
    this.name = other.name;
    this.phone = other.phone;
    this.faceId = other.faceId;
    this.angleX = other.angleX;
    this.angleY = other.angleY;
    this.angleZ = other.angleZ;
    this.x = other.x;
    this.y = other.y;
    this.w = other.w;
    this.h = other.h;
    this.image = other.image;
    this.lastest = DateTime.now().millisecondsSinceEpoch;
    this.timecheck = other.timecheck;
    this.busy = other.busy;
    this.check = other.check;
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

  double s_x1 = 0.6;
  double s_x2 = 0.6;
  double s_y1 = 0.75;
  double s_y2 = 0.85;

  late APICamera camera;

  StreamController streamPersonController = StreamController.broadcast();

  APIFace() {
    camera = APICamera(CameraLensDirection.front);
  }

  void init(RootIsolateToken rootIsolateToken) {
    camera.init(rootIsolateToken);

    camera.streamDectectFaceController.stream.listen((event) {
      if (event is List) {
        if (event[0] is List<Face> && event[1] is imglib.Image) {
          List<Face> faces = event[0];
          print('[Debug face] Size : ${faces.length}');
          imglib.Image img = event[1];

          if (faces.length > 0) {
            for (int i = 0; i < faces.length; i++) {
              print('[Debug face] Info Face : $i - ${faces[i].trackingId}');
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
                          int x1 = (persons[j].x - persons[j].w * s_x1).toInt();
                          int y1 = (persons[j].y - persons[j].h * s_y1).toInt();
                          int x2 = (persons[j].x + persons[j].w * s_x2).toInt();
                          int y2 = (persons[j].y + persons[j].h * s_y2).toInt();

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
                          persons[j].image = Uint8List.fromList(
                            imglib.encodeJpg(buffer, quality: 90),
                          );
                          persons[j].busy = true;
                          persons[j].check = true;
                        }
                      }
                      flag = true;
                      break;
                    }
                  }

                  if (flag == false) {
                    print(
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
                      int x1 = (info.x - info.w * s_x1).toInt();
                      int y1 = (info.y - info.h * s_y1).toInt();
                      int x2 = (info.x + info.w * s_x2).toInt();
                      int y2 = (info.y + info.h * s_y2).toInt();

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
                } else {
                  print(
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
                    int x1 = (info.x - info.w * s_x1).toInt();
                    int y1 = (info.y - info.h * s_y1).toInt();
                    int x2 = (info.x + info.w * s_x2).toInt();
                    int y2 = (info.y + info.h * s_y2).toInt();

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

          print('[Debug face] : length ${persons.length}');

          if (persons.isNotEmpty) {
            print('[Debug face] : * length ${persons.length}');
            for (int i = 0; i < persons.length; i++) {
              if (persons[i].check == true) {
                int time =
                    DateTime.now().millisecondsSinceEpoch -
                    persons[i].timecheck;
                if (time > 2000) {
                  print(
                    '[Debug face] : detected face ${i} : ${persons[i].faceId}',
                  );
                  print(
                    '[Face] : ${persons[i].faceId} - ${persons[i].lastest} | ${persons[i].angleX} , ${persons[i].angleY} , ${persons[i].angleZ} - ${persons[i].image.length} - ${persons[i].w} x ${persons[i].h}',
                  );
                  persons[i].busy = false;
                  persons[i].check = false;
                  persons[i].timecheck = DateTime.now().millisecondsSinceEpoch;
                  streamPersonController.sink.add([persons[i].faceId]);
                }
              } else {
                print(
                  '[Debug face] : dont detect face ${i} : ${persons[i].faceId}',
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
    if (camera.state() == true) {
      camera.stop();
      persons.clear();
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
}
