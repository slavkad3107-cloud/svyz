import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

const String appId = "7db3907e5c6a46139446d6541f488661";

void main() => runApp(const MaterialApp(home: RoomSelection()));

class RoomSelection extends StatefulWidget {
  const RoomSelection({super.key});
  @override
  State<RoomSelection> createState() => _RoomSelectionState();
}

class _RoomSelectionState extends State<RoomSelection> {
  final _controller = TextEditingController(text: "777");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("ВОЙТИ В РАЦИЮ",
                style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "ID Канала",
                labelStyle: TextStyle(color: Colors.orange),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            WalkieTalkie(channel: _controller.text)));
              },
              child: const Text("ПОДКЛЮЧИТЬСЯ",
                  style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      ),
    );
  }
}

class WalkieTalkie extends StatefulWidget {
  final String channel;
  const WalkieTalkie({super.key, required this.channel});
  @override
  State<WalkieTalkie> createState() => _WalkieTalkieState();
}

class _WalkieTalkieState extends State<WalkieTalkie> {
  late RtcEngine _engine;
  bool _isTalking = false;
  bool _init = false;
  int? _remoteUid; // ID собеседника (если null — никого нет)
  final List<String> _chat = [];
  final _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Permission.microphone.request();
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: appId));

    _engine.registerEventHandler(RtcEngineEventHandler(
      // Когда кто-то заходит в канал
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        setState(() => _remoteUid = remoteUid);
      },
      // Когда кто-то выходит
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        setState(() => _remoteUid = null);
      },
      onStreamMessage: (RtcConnection connection, int remoteUid, int streamId,
          Uint8List data, int length, int sentTs) {
        setState(
            () => _chat.insert(0, "Партнер: ${String.fromCharCodes(data)}"));
      },
    ));

    await _engine
        .setChannelProfile(ChannelProfileType.channelProfileCommunication);
    await _engine.joinChannel(
        token: '',
        channelId: widget.channel,
        uid: 0,
        options: const ChannelMediaOptions());
    await _engine.muteLocalAudioStream(true);
    setState(() => _init = true);
  }

  void _sendMsg() async {
    if (_msgController.text.isEmpty) return;
    final data = Uint8List.fromList(_msgController.text.codeUnits);
    int streamId = await _engine.createDataStream(
        const DataStreamConfig(syncWithAudio: false, ordered: true));
    await _engine.sendStreamMessage(
        streamId: streamId, data: data, length: data.length);
    setState(() {
      _chat.insert(0, "Я: ${_msgController.text}");
      _msgController.clear();
    });
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isPartnerOnline = _remoteUid != null;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Канал: ${widget.channel}"),
            Text(
              isPartnerOnline
                  ? "● Собеседник в сети"
                  : "○ Ожидание партнера...",
              style: TextStyle(
                  fontSize: 12,
                  color: isPartnerOnline ? Colors.greenAccent : Colors.white54),
            ),
          ],
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
              child: ListView.builder(
                  reverse: true,
                  itemCount: _chat.length,
                  itemBuilder: (context, i) => ListTile(
                      title: Text(_chat[i],
                          style: const TextStyle(color: Colors.white70))))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white))),
              IconButton(
                  icon: const Icon(Icons.send, color: Colors.orange),
                  onPressed: _sendMsg),
            ]),
          ),
          const SizedBox(height: 20),
          if (_init)
            GestureDetector(
              onLongPressStart: (_) {
                if (isPartnerOnline) {
                  setState(() => _isTalking = true);
                  _engine.muteLocalAudioStream(false);
                }
              },
              onLongPressEnd: (_) {
                setState(() => _isTalking = false);
                _engine.muteLocalAudioStream(true);
              },
              child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !isPartnerOnline
                          ? Colors.grey
                          : (_isTalking ? Colors.red : Colors.orange)),
                  child: Icon(isPartnerOnline ? Icons.mic : Icons.mic_off,
                      size: 60, color: Colors.black)),
            )
          else
            const CircularProgressIndicator(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
