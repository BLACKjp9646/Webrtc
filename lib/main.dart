import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class VideoCallPage extends StatefulWidget {
  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  late RTCVideoRenderer _localRenderer;
  late WebSocketChannel _channel;
  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;
  String serverUrl = "ws://10.0.105.208:8080"; // MacOSのIPアドレスとポート

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _initializeWebSocket();
    _initializeMedia();
  }

  // WebSocket接続の初期化
  void _initializeWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _channel.stream.listen((message) {
      // 受信したメッセージに応じて処理
      final data = json.decode(message);
      if (data['type'] == 'offer') {
        _createAnswer(data['sdp']);
      } else if (data['type'] == 'answer') {
        _setRemoteDescription(data['sdp']);
      } else if (data['type'] == 'ice_candidate') {
        _addIceCandidate(data['candidate']);
      }
    });
  }

  // メディアストリームの初期化
  Future<void> _initializeMedia() async {
    _localRenderer.initialize();
    _localStream = await navigator.mediaDevices.getUserMedia({
      'video': {'facingMode': 'environment', 'width': 1920, 'height': 1080},
      'audio': true,
    });
    _localRenderer.srcObject = _localStream;
    
    _peerConnection = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
    });

    // ローカルメディアをPeerConnectionに追加
    _localStream.getTracks().forEach((track) {
      _peerConnection.addTrack(track, _localStream);
    });
  }

  // オファーの作成
  Future<void> _createOffer() async {
    RTCSessionDescription offer = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(offer);
    
    _channel.sink.add(json.encode({
      'type': 'offer',
      'sdp': offer.sdp,
    }));
  }

  // アンサーの作成
  Future<void> _createAnswer(String offerSdp) async {
    RTCSessionDescription offer = RTCSessionDescription(offerSdp, 'offer');
    await _peerConnection.setRemoteDescription(offer);
    
    RTCSessionDescription answer = await _peerConnection.createAnswer();
    await _peerConnection.setLocalDescription(answer);

    _channel.sink.add(json.encode({
      'type': 'answer',
      'sdp': answer.sdp,
    }));
  }

  // リモートのSDP設定
  Future<void> _setRemoteDescription(String sdp) async {
    RTCSessionDescription remoteDescription = RTCSessionDescription(sdp, 'answer');
    await _peerConnection.setRemoteDescription(remoteDescription);
  }

  // ICE Candidateの追加
  void _addIceCandidate(Map<String, dynamic> candidateData) {
    RTCIceCandidate candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );
    _peerConnection.addCandidate(candidate);
  }

  // WebSocketメッセージ送信
  void _sendIceCandidate(RTCIceCandidate candidate) {
    _channel.sink.add(json.encode({
      'type': 'ice_candidate',
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    }));
  }

  @override
  void dispose() {
    _channel.sink.close();
    _localStream.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WebRTC Video Call')),
      body: Center(
        child: RTCVideoView(_localRenderer),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createOffer,
        child: Icon(Icons.call),
      ),
    );
  }
}
