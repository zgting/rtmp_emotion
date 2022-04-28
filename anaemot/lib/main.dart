import 'dart:async';
import 'dart:io';
import 'package:anaemot/pushlive/push.dart';
import 'package:anaemot/utils/PhonePermissionUtils.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:isolate';
import 'package:device_info/device_info.dart';
// ignore: import_of_legacy_library_into_null_safe

//每种情绪以及对应的占比Emotion
class Emotion {
  String emotionText = ""; //什么情绪
  String emotionChina = ""; //中文
  double emotionValue = 0.0; //该情绪的占比
}

//人脸类 各种情绪
class Person {
  String posturl = "";
  //需要显示的信息
  String dominantemotion = "NULL"; //主要的表情
  List<Emotion> emotion = [];
  bool isface = false;
  Color textcolor = Colors.black;
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    PhonePermissionUtils.checkPermission().then((onValue) {});
    return MaterialApp(
      title: '智能情感分析',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State {
  //获取设备码
  Future<String> getUniqueId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await deviceInfo.iosInfo;
      print("ios唯一设备码:" + iosDeviceInfo.identifierForVendor);
      return iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else {
      AndroidDeviceInfo androidDeviceInfo = await deviceInfo.androidInfo;
      print("android唯一设备码:" + androidDeviceInfo.androidId);
      return androidDeviceInfo.androidId; // unique ID on Android
    }
  }

  String device = "";
  get() async {
    await getUniqueId().then((value) {
      setState(() {
        device = value;
        rtmpurl = rtmpurl + value;
      });
    });
  }

  @override
  initState() {
    super.initState();
    get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.blueGrey,
        child: Center(
          child: device == ""
              ? Text("")
              : ListView(
                  scrollDirection: Axis.vertical,
                  children: [
                    PushLive(),
                    Divider(),
                    BuildEmotion(),
                  ],
                ),
        ),
      ),
    );
  }
}

class BuildEmotion extends StatefulWidget {
  BuildEmotion({Key? key}) : super(key: key);

  @override
  State<BuildEmotion> createState() => _BuildEmotionState();
}

class _BuildEmotionState extends State<BuildEmotion> {
  Person _person = Person();
  bool _isprocess = false;
  bool _ispost = false;
  //  post
  TextEditingController _postcontroller = TextEditingController();
  String _posturl = "http://192.168.145.78:5000/rtmpanalyze";

  int isChinese = 1;
  Map<String, dynamic> rtmpData = Map();

  //初始化表情参数
  void _initialEmotion() {
    List em = [
      ["neutral", "中立"],
      ["happy", "高兴"],
      ["disgust", "厌恶"],
      ["fear", "害怕"],
      ["sad", "伤心"],
      ["surprise", "惊喜"],
      ["angry", "生气"]
    ];
    for (var item in em) {
      Emotion emotion = Emotion();
      emotion.emotionText = item[0];
      emotion.emotionChina = item[1];
      _person.emotion.add(emotion);
    }
  }

  @override
  void initState() {
    super.initState();
    _postcontroller.text = _posturl;
    //初始话表情类
    _initialEmotion();
  }

  //进行post
  _dealimage() async {
    rtmpData["isChange"] = true;
    rtmpData["status"] = true;
    rtmpData["rtmp_url"] = rtmpurl;

    while (!_isprocess) {
      _isprocess = true;
      if (!_ispost) {
        // 结束post
        rtmpData["isChange"] = true;
        rtmpData["status"] = false;
        rtmpData["rtmp_url"] = rtmpurl;
        // 启动post获取结果
        ReceivePort receivePort = ReceivePort();
        await Isolate.spawn(solve, receivePort.sendPort);
        SendPort sendPort = await receivePort.first;
        ReceivePort response = ReceivePort();
        sendPort.send([rtmpData, _person, response.sendPort]);
        Person msg = await response.first;
        setState(() {
          if (msg.isface) {
            _person = msg;
          }
        });
        _isprocess = false;
        break;
      }
      // 启动post获取结果
      ReceivePort receivePort = ReceivePort();
      await Isolate.spawn(solve, receivePort.sendPort);
      SendPort sendPort = await receivePort.first;
      ReceivePort response = ReceivePort();
      sendPort.send([rtmpData, _person, response.sendPort]);
      Person msg = await response.first;
      setState(() {
        rtmpData["isChange"] = false;
        rtmpData["status"] = true;
        rtmpData["rtmp_url"] = rtmpurl;
        if (msg.isface) {
          _person = msg;
        }
      });
      _isprocess = false;
    }
  }

//对图片的主要处理线程
  static Future<void> solve(SendPort sendPort) async {
    sleep(Duration(seconds: 1));
    ReceivePort port = ReceivePort();
    sendPort.send(port.sendPort);
    List msg = await port.first;
    Map rtmpData = msg[0];
    SendPort replyto = msg[2];
    Person person = await _postRequest(rtmpData, msg[1]);
    replyto.send(person);
  }

  ///post请求发送json
  static Future<Person> _postRequest(Map map, Person person) async {
    BaseOptions ops = BaseOptions(
      //两秒连不上就切换服务器
      connectTimeout: 2000,
      // 响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: 2000,
    );

    ///创建Dio
    Dio dio = new Dio(ops);

    ///发起post请求
    Response response;
    try {
      response = await dio.post(person.posturl,
          data: map, options: Options(responseType: ResponseType.plain));
      //能到这里就说明检测到脸了
      var data = response.data;
      var ma = jsonDecode(data.toString()); //字符串转map
      // 给结果赋值
      person.isface = true;
      for (var item in person.emotion) {
        item.emotionValue = ma[item.emotionText];
      }
    } on DioError catch (e) {
      print(e.toString());
    }
    return person;
  }

  //显示表情
  Widget buildEmotion() {
    Widget content; //单独一个widget组件，用于返回需要生成的内容widget
    List<Widget> tiles = []; //先建一个数组用于存放循环生成的widget

    for (var item in _person.emotion) {
      tiles.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: emotionInfo(item),
        ),
      );
    }
    content = Column(
      children: tiles,
    );
    return content;
  }

  //显示的表情信息
  List<Widget> emotionInfo(Emotion item) {
    return [
      Container(
        padding: EdgeInsets.only(left: 10, bottom: 5),
        width: MediaQuery.of(context).size.width / 5,
        child: Text(
          isChinese == 1 ? item.emotionChina : item.emotionText,
          style: TextStyle(color: _person.textcolor),
        ),
      ),
      Container(
        padding: EdgeInsets.only(right: 5, top: 4),
        width: MediaQuery.of(context).size.width * 4 / 5,
        child: LinearPercentIndicator(
          animation: true,
          lineHeight: 20.0,
          animationDuration: 250,
          percent: item.emotionValue / 100,
          center: Text(item.emotionValue.toStringAsFixed(4) + "%"),
          linearStrokeCap: LinearStrokeCap.roundAll,
          animateFromLastPercent: true,
          linearGradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment(2.0, 2.0),
            colors: [Colors.green, Colors.red],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(rtmpData.toString()),
        TextField(
          controller: _postcontroller,
          onChanged: (value) {
            _posturl = value;
            _person.posturl = value;
          },
          decoration: new InputDecoration(
            labelText: "Post Url",
          ),
        ),
        Divider(),
        makeButton(
            icon: null,
            text: _ispost == true ? "stop" : "post",
            func: () {
              setState(() {
                _ispost = !_ispost;
              });

              if (_ispost) _dealimage();
            }),
        buildEmotion(),
      ],
    );
  }

  Widget makeButton({IconData? icon, String? text, Function? func}) {
    return Container(
      padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
      constraints: BoxConstraints(maxWidth: 170),
      // width: 150,
      height: 50,
      child: ElevatedButton(
        child: Row(
          children: <Widget>[
            Icon(icon),
            Text(text!),
          ],
        ),
        onPressed: () {
          func!();
        },
      ),
    );
  }
}
