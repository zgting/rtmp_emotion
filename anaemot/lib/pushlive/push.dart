import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_rtmp_publisher/flutter_rtmp_publisher.dart';

import '../language.dart';

String rtmpurl = "rtmp://118.195.200.217/live/";

class PushLive extends StatefulWidget {
  PushLive({Key? key}) : super(key: key);

  @override
  State<PushLive> createState() => _PushLiveState();
}

class _PushLiveState extends State<PushLive> {
  final RTMPCamera cameraController = RTMPCamera();
  final StreamController<List<CameraSize>> streamController =
      StreamController<List<CameraSize>>();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: RTMPCameraPreview(
          controller: this.cameraController,
          createdCallback: (int id) {
            this.cameraController.getResolutions().then((resolutionList) {
              streamController.add(resolutionList);
            });
          },
        ),
      ),
      Container(
        // height: 200,
        child: LivePushController(
          cameraController: cameraController,
          resolutionStream: streamController.stream,
        ),
      ),
    ]);
  }
}

class LivePushController extends StatefulWidget {
  final RTMPCamera cameraController;
  final Stream<List<CameraSize>> resolutionStream;
  LivePushController({
    Key? key,
    required this.cameraController,
    required this.resolutionStream,
  }) : super(key: key);

  @override
  _LivePushController createState() => _LivePushController();
}

class _LivePushController extends State<LivePushController> {
  late TextEditingController textController;

  final videoBitrateController = TextEditingController(text: "2560000");
  final fpsController = TextEditingController(text: "30");
  final audioBitrateController = TextEditingController(text: "128");
  final sampleRateController = TextEditingController(text: "44100");
  final usernameController = TextEditingController(text: "");
  final passwordController = TextEditingController(text: "");
  bool hardwareController = false;
  bool echoCancelerController = false;
  bool noiseSuppressorController = false;

  Language lang = language[1].useThis();
  late CameraSize size;

  bool onPreview = false;
  bool isStreaming = false;
  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: rtmpurl);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          TextField(
            controller: textController,
            decoration: new InputDecoration(
              labelText: lang.address,
            ),
            onChanged: (value) => rtmpurl = value,
          ),
          languageChooser(),
          Divider(),
          buttonArea(),
          Divider(),
          settingArea(),
        ],
      ),
    );
  }

  makeToast({String? text, String? action, Function? callback}) {
    // hide the last snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
      content: new Text(text!),
      action: action != null
          ? SnackBarAction(
              label: action,
              onPressed: () => callback == null
                  ? ScaffoldMessenger.of(context).hideCurrentSnackBar()
                  : callback,
            )
          : null,
    ));
  }

  Widget languageChooser() {
    return Container(
      child: Wrap(
        // spacing: 8.0,
        // runSpacing: 4.0,
        children: List.generate(
          language.length,
          (index) {
            return Checker(
              text: language[index].language,
              value: language[index].use,
              callbackFunc: (value) {
                setState(() {
                  for (var l in language) {
                    l.use = false;
                  }
                  lang = language[index].useThis();
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget makeTextField(String label, TextEditingController controller) {
    return Container(
      width: 150,
      child: TextField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: new InputDecoration(
          labelText: label,
        ),
        controller: controller,
      ),
    );
  }

  Widget settingArea() {
    return Container(
      color: Colors.grey,
      alignment: Alignment(0, 0),
      child: Column(
        children: <Widget>[
          Text(
            lang.video,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ResolutionChooser(
            stream: this.widget.resolutionStream,
            lang: lang,
            callbackFunc: (CameraSize size) {
              this.size = size;
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              makeTextField(lang.videoBitrate, videoBitrateController),
              makeTextField(lang.audioBitrate, audioBitrateController),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              makeTextField(lang.fps, fpsController),
              Checker(
                text: this.lang.hardwareRotation,
                value: this.hardwareController,
                callbackFunc: (value) {
                  setState(() {
                    this.hardwareController = value;
                  });
                },
              ),
            ],
          ),
          Text(
            this.lang.audio,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              makeTextField(lang.audioBitrate, audioBitrateController),
              makeTextField(lang.sampleRate, sampleRateController),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Checker(
                text: this.lang.noiseSuppressor,
                value: this.noiseSuppressorController,
                callbackFunc: (value) {
                  setState(() {
                    this.noiseSuppressorController = value;
                  });
                },
              ),
              Checker(
                text: this.lang.echoCanceler,
                value: this.echoCancelerController,
                callbackFunc: (value) {
                  setState(() {
                    this.echoCancelerController = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buttonArea() {
    return Container(
      padding: EdgeInsets.all(10),
      alignment: Alignment(0, 0),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: <Widget>[
          this.previewButton(),
          this.streamButton(),
          makeButton(
              icon: Icons.switch_camera,
              text: lang.switchCamera,
              func: () {
                this.widget.cameraController.switchCamera();
              }),
        ],
      ),
    );
  }

  Future<bool> prepareEncode() async {
    return await this.widget.cameraController.prepareAudio(
              bitrate: int.parse(this.audioBitrateController.text),
              sampleRate: int.parse(this.sampleRateController.text),
              echoCanceler: this.echoCancelerController,
              noiseSuppressor: this.noiseSuppressorController,
            ) &&
        await this.widget.cameraController.prepareVideo(
              width: this.size.width,
              height: this.size.height,
              fps: int.parse(this.fpsController.text),
              bitrate: int.parse(this.videoBitrateController.text),
              hardwareRotation: this.hardwareController,
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

  Widget previewButton() {
    if (!this.onPreview) {
      return makeButton(
        icon: Icons.play_circle_filled,
        text: lang.startPreview,
        func: () async {
          if (this.size == null) {
            makeToast(text: lang.errorResolutionFirst, action: lang.gotIt);
          } else {
            if (await this.prepareEncode()) {
              await this.widget.cameraController.startPreview();
              this.widget.cameraController.onPreview().then((preview) {
                setState(() {
                  this.onPreview = preview;
                });
              });
            } else {
              makeToast(text: "Error");
            }
          }
        },
      );
    } else {
      return makeButton(
        icon: Icons.pause_circle_filled,
        text: lang.stopPreview,
        func: () async {
          await this.widget.cameraController.stopPreview();
          this.widget.cameraController.onPreview().then((preview) {
            setState(() {
              this.onPreview = preview;
            });
          });
        },
      );
    }
  }

  Widget streamButton() {
    if (!this.isStreaming) {
      return makeButton(
        icon: Icons.play_circle_filled,
        text: lang.startStream,
        func: () async {
          if (await this.widget.cameraController.onPreview() == false ||
              await this.prepareEncode()) {
            await this.widget.cameraController.startStream(rtmpurl);

            this.widget.cameraController.isStreaming().then((streaming) {
              setState(() {
                this.isStreaming = streaming;
              });
            });
          } else {
            makeToast(text: "Error!");
          }
        },
      );
    } else {
      return makeButton(
        icon: Icons.pause_circle_filled,
        text: lang.stopStream,
        func: () async {
          await this.widget.cameraController.stopStream();
          this.widget.cameraController.isStreaming().then((streaming) {
            setState(() {
              this.isStreaming = streaming;
            });
          });
        },
      );
    }
  }
}

/* 
  Dropdown
*/

class ResolutionChooser extends StatefulWidget {
  final Stream<List<CameraSize>> stream;
  final Language lang;
  final CameraSizeCallback callbackFunc;

  ResolutionChooser({
    Key? key,
    required this.stream,
    required this.lang,
    required this.callbackFunc,
  }) : super(key: key);

  @override
  _ResolutionChooserState createState() => _ResolutionChooserState();
}

class _ResolutionChooserState extends State<ResolutionChooser> {
  late List<CameraSize> resolutionList = [];
  late CameraSize size;
  late int selected;

  late StreamSubscription<List<CameraSize>> listener;

  @override
  void initState() {
    super.initState();
    listener = this.widget.stream.listen((rl) {
      if (resolutionList.length <= 0) {
        setState(() {
          this.resolutionList = rl;
          if (rl.length > 0) {
            this.selected = 0;
            this.widget.callbackFunc(rl[0]);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    if (this.listener != null) {
      this.listener.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this.resolutionList == null
        ? Text(this.widget.lang.resolutionIsLoding)
        : DropdownButtonHideUnderline(
            child: DropdownButton(
              items: List.generate(this.resolutionList.length, (index) {
                CameraSize resolution = this.resolutionList[index];
                return DropdownMenuItem(
                  value: index,
                  child: new Text("${resolution.width}×${resolution.height}"),
                );
              }),
              hint: Text(this.widget.lang.resolutionFirst),
              value: selected,
              onChanged: (value) {
                int i = value as int;
                if (this.widget.callbackFunc != null) {
                  this.widget.callbackFunc(this.resolutionList[i]);
                }
                setState(() {
                  this.selected = i;
                });
              },
            ),
          );
  }
}

class Checker extends StatefulWidget {
  final Function callbackFunc;
  final String text;
  final bool value;
  Checker(
      {Key? key,
      required this.callbackFunc,
      required this.text,
      required this.value})
      : super(key: key);

  @override
  _CheckerState createState() => _CheckerState(value: value);
}

class _CheckerState extends State<Checker> {
  bool value;

  _CheckerState({required this.value}) : super();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Checkbox(
          value: this.widget.value, //当前状态
          onChanged: (value) {
            if (this.widget.callbackFunc != null) {
              this.widget.callbackFunc(value);
            }
          },
        ),
        Text(this.widget.text),
      ],
    );
  }
}
