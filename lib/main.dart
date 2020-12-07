import 'dart:convert';
import 'dart:typed_data';

import 'package:android_intent/android_intent.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_voice/commands.dart';
import 'package:flutter_voice/palette.dart';
import 'package:flutter_voice/switch-item.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'home_automation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Palette.colorPrimary,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SpeechScreen(),
    );
  }
}

class SpeechScreen extends StatefulWidget {
  @override
  _SpeechScreenState createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  stt.SpeechToText _speech;
  FlutterTts flutterTts;

  bool _isListening = false;
  String _text = 'Press the button and start speaking';
  double _confidence = 1.0;
  List<int> switchIndices = [0, 1, 2, 3];
  List<bool> switchLoading = [false, false, false, false];
  List<bool> switchStates = [false, false, false, false];

//  FlutterBlue flutterBlue = FlutterBlue.instance;
  bool _deviceFound = false;
  Timer _timer;
  BluetoothConnection connection;

  bool isConnecting = true;

  BuildContext scaffoldContext = null;

  bool get isConnected => connection != null && connection.isConnected;
  bool isDisconnecting = false;

  String _messageBuffer = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    init();
    _checkForDevice();
    _timer = new Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      _checkForDevice();
    });
  }

  init() async {
    flutterTts = FlutterTts();
    await flutterTts.setPitch(1.1);
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }
    scaffoldContext = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Home Automation'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Builder(
        builder: (scaffoldContext) => AvatarGlow(
          animate: _isListening,
          glowColor: Palette.colorSecondary,
          endRadius: 75.0,
          duration: const Duration(milliseconds: 2000),
          repeatPauseDuration: const Duration(milliseconds: 100),
          repeat: true,
          child: FloatingActionButton(
            backgroundColor: isConnected ? Palette.colorSecondary : Palette.colorGray,
            onPressed: !isConnected
                ? null
                : () {
                    _listen(scaffoldContext);
                  },
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
        ),
      ),
      body: Builder(builder: (scaffoldContext) {
        this.scaffoldContext = scaffoldContext;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.1, 0.4, 0.7, 0.9],
              colors: [
                Color(0xFF3594DD),
                Color(0xFF4563DB),
                Color(0xFF5036D5),
                Color(0xFF5B16D0),
              ],
            ),
          ),
          child: Column(
            children: [
              Flexible(
                child: ListView(
                  children: [
                    ...switchIndices.map((i) => SwitchItem(
                          label: 'Light ${i + 1}',
                          value: switchStates[i],
                          disabled: !isConnected,
                          noTouch: switchLoading[0] ||
                              switchLoading[1] ||
                              switchLoading[2] ||
                              switchLoading[3],
                          isLoading: switchLoading[i],
                          onChange: (value) {
                            setState(() {
                              switchStates[i] = value;
                              switchLoading[i] = true;
                              _sendMessage(
                                  "${switchStates[0]} ${switchStates[1]} ${switchStates[2]} ${switchStates[3]}");
                            });
                          },
                        )),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                      child: _deviceFound
                          ? Center(
                              child: isConnecting
                                  ? Text('Wait until connected...',
                                      style: TextStyle(
                                          fontSize: 14.0,
                                          color: Palette.colorWhite.withAlpha(200)))
                                  : isConnected
                                      ? Text('Device connected',
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              color: Palette.colorWhite.withAlpha(200)))
                                      : Text(
                                          'device got disconnected',
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              color: Palette.colorWhite.withAlpha(200)),
                                        ))
                          : (RaisedButton(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0)),
                              padding: EdgeInsets.all(16.0),
                              color: Palette.colorPrimary,
                              onPressed: _jumpToSettings,
                              child: Text(
                                "CONNECT DEVICE",
                                style: TextStyle(color: Palette.colorWhite),
                              ))),
                    )
                  ],
                ),
              ),
              Container(
                  padding: const EdgeInsets.fromLTRB(30.0, 30.0, 30.0, 150.0),
                  child: Text(
                    _text,
                    style: TextStyle(fontSize: 18.0, color: Palette.colorWhite),
                  )),
            ],
          ),
        );
      }),
    );
  }

  void _listen(scaffoldContext) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          print('onStatus: $val');
          if (val == 'notListening') {
            Future.delayed(Duration(seconds: 1), () {
              _speak();
              _interpretSpeech(_text);
            });
            setState(() {
              print('onStatus: $val');
              _isListening = false;
            });
          }
        },
        onError: (val) {
          setState(() {
            _isListening = false;
            _text = '';
          });
          if (val.errorMsg.contains("error_no_match")) {
            Scaffold.of(scaffoldContext)
                .showSnackBar(SnackBar(content: Text("Couldn't understand you.")));
          }
          print('onError: $val');
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords.replaceAll("to", "two").replaceAll("forth", "fourth").replaceAll("fort", "fourth");
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _interpretSpeech(String speechText) {
    if (light1On.contains(speechText)) {
      _sendMessage("true ${switchStates[1]} ${switchStates[2]} ${switchStates[3]}");
    } else if (light1Off.contains(speechText)) {
      _sendMessage("false ${switchStates[1]} ${switchStates[2]} ${switchStates[3]}");
    } else if (light2On.contains(speechText)) {
      _sendMessage("${switchStates[0]} true ${switchStates[2]} ${switchStates[3]}");
    } else if (light2Off.contains(speechText)) {
      _sendMessage("${switchStates[0]} false ${switchStates[2]} ${switchStates[3]}");
    } else if (light3On.contains(speechText)) {
      _sendMessage("${switchStates[0]} ${switchStates[1]} true ${switchStates[3]}");
    } else if (light3Off.contains(speechText)) {
      _sendMessage("${switchStates[0]} ${switchStates[1]} false ${switchStates[3]}");
    } else if (light4On.contains(speechText)) {
      _sendMessage("${switchStates[0]} ${switchStates[1]} ${switchStates[2]} true");
    } else if (light4Off.contains(speechText)) {
      _sendMessage("${switchStates[0]} ${switchStates[1]} ${switchStates[2]} false");
    } else if (allLightsOn.contains(speechText)) {
      _sendMessage("true true true true");
    } else if (allLightsOff.contains(speechText)) {
      _sendMessage("false false false false");
    } else {
      List<String> state = [
        '${switchStates[0]}',
        '${switchStates[1]}',
        '${switchStates[2]}',
        '${switchStates[3]}'
      ];
      if (speechText.contains("off ") || speechText.contains(" off")) {
        if (speechText.contains(RegExp("one|1|first"))) {
          state[0] = "false";
        }
        if (speechText.contains(RegExp("two|2|second"))) {
          state[1] = "false";
        }
        if (speechText.contains(RegExp("three|3|third"))) {
          state[2] = "false";
        }
        if (speechText.contains(RegExp("four|4|fourth"))) {
          state[3] = "false";
        }
        _sendMessage(state.join(" "));
      } else if (speechText.contains("on ") || speechText.contains(" on")) {
        if (speechText.contains(RegExp("one|1|first"))) {
          state[0] = "true";
        }
        if (speechText.contains(RegExp("two|2|second"))) {
          state[1] = "true";
        }
        if (speechText.contains(RegExp("three|3|third"))) {
          state[2] = "true";
        }
        if (speechText.contains(RegExp("four|4|fourth"))) {
          state[3] = "true";
        }
        _sendMessage(state.join(" "));
      }
    }
  }

  _jumpToSettings() async {
    FlutterBluetoothSerial.instance.openSettings();
  }

  _checkForDevice() {
    FlutterBluetoothSerial.instance
        .getBondedDevices()
        .then((List<BluetoothDevice> bondedDevices) {
      var device =
          bondedDevices.firstWhere((element) => element.name == 'BT04-A', orElse: () => null);

      if (device == null) {
        setState(() {
          _deviceFound = false;
        });
      } else {
        setState(() {
          _deviceFound = true;

          BluetoothConnection.toAddress(device.address).then((_connection) {
            print('Connected to the device');
            connection = _connection;
            setState(() {
              isConnecting = false;
              isDisconnecting = false;
            });

            connection.input.listen(_onDataReceived).onDone(() {
              // Example: Detect which side closed the connection
              // There should be `isDisconnecting` flag to show are we are (locally)
              // in middle of disconnecting process, should be set before calling
              // `dispose`, `finish` or `close`, which all causes to disconnect.
              // If we except the disconnection, `onDone` should be fired as result.
              // If we didn't except this (no flag set), it means closing by remote.

              _timer.cancel();
              _timer = new Timer.periodic(const Duration(seconds: 2), (Timer timer) {
                _checkForDevice();
              });
              if (isDisconnecting) {
                print('Disconnecting locally!');
              } else {
                print('Disconnected remotely!');
              }
              if (this.mounted) {
                setState(() {});
              }
            });
          }).catchError((error) {
            print('Cannot connect, exception occurred');
            print(error);
          });
        });

        _timer.cancel();
      }
    });
  }

  Future _speak() async {
    await flutterTts.speak(_text);
  }

  void _sendMessage(String text) async {
    text = text.trim();
    text = '$text#';
    if (text.length > 0) {
      try {
        connection.output.add(utf8.encode(text + "\r\n"));
        await connection.output.allSent;
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      var received = backspacesCounter > 0
          ? _messageBuffer.substring(0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString.substring(0, index);

      _messageBuffer = dataString.substring(index);

      try {
        var json = jsonDecode(received);
        print(json);
        setState(() {
          switchStates = List<bool>.from(json["state"]);
          switchLoading = [false, false, false, false];
        });
      } catch (e) {
        Scaffold.of(scaffoldContext).showSnackBar(SnackBar(
          content: Text("Oops! Something went wrong. Try restarting the app"),
          duration: Duration(seconds: 3),
        ));
      }
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }
}

