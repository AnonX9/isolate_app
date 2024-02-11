import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';

class Worker {
  late SendPort _mainThreadSendPort;
  late ReceivePort _workerReceivePort;
  late SendPort _workerSendPort;
  bool _isolateRunning = false;
  Timer? _apiRequestTimer;
  late StreamController<dynamic> _responseController;
  bool _isPhoneRinging = false;
  Completer<void> _apiCallCompleter = Completer<void>();

  static const String _apiUrl = "https://csrng.net/csrng/csrng.php?min=0&max=1";
  static const Duration _apiRequestInterval = Duration(seconds: 5);

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 5000),
      receiveTimeout: const Duration(milliseconds: 5000),
    ),
  );

  Worker(this._workerReceivePort, this._mainThreadSendPort) {
    _responseController = StreamController<dynamic>.broadcast();
    _workerSendPort = _workerReceivePort.sendPort;
  }

  Future<void> initialize() async {
    _mainThreadSendPort.send('initialize');
    _startApiRequests();
  }

  Stream<dynamic> get responseStream => _responseController.stream;

  void _startApiRequests() {
    _isolateRunning = true;
    _apiRequestTimer = Timer.periodic(_apiRequestInterval, _requestApiData);
  }

  Future<void> _requestApiData(Timer timer) async {
    try {
      _apiCallCompleter = Completer<void>();

      if (!_isPhoneRinging && !_apiCallCompleter.isCompleted) {
        var number = await _getNumber();
        print("Received number from API: $number");

        _responseController.add(number);

        if (number == 1) {
          _isPhoneRinging = true;
          _responseController.add("Phone Ringing");
          await _ringPhone();
          _isPhoneRinging = false;
        }
      } else {
        print("API call skipped due to phone ringing or in progress");
      }
    } catch (e) {
      print("Error during API request: $e");
    } finally {
      _apiCallCompleter.complete();
    }
  }

  Future<void> _ringPhone() async {
    for (var i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(seconds: 1), () {
        print("Phone Ringing $i times!");
      });
    }
  }

  void _stopApiRequests() {
    _isolateRunning = false;
    _apiRequestTimer?.cancel();
  }

  static Future<Worker> init() async {
    final receivePort = ReceivePort();
    Isolate.spawn(_startIsolate, receivePort.sendPort);
    final mainThreadSendPort = await receivePort.first;
    return Worker(receivePort, mainThreadSendPort);
  }

  static void _startIsolate(SendPort mainThreadSendPort) {
    final workerPort = ReceivePort();
    mainThreadSendPort.send(workerPort.sendPort);

    final worker = Worker(workerPort, mainThreadSendPort);
    worker.initialize();

    workerPort.listen((message) {
      if (message == 'shutdown') {
        worker._stopApiRequests();
        worker._workerSendPort.send('shutdown');
        workerPort.close();
        print('--- Worker Isolate Closed ---');
      }
    });
  }

  void close() {
    if (_isolateRunning) {
      _workerSendPort.send('shutdown');
      _responseController.close();
    }
  }

  static Future<int> _getNumber() async {
    Response response = await _dio.get(_apiUrl);
    print("API Response: ${response.data}");

    var random = response.data[0]['random'];

    return random;
  }
}
