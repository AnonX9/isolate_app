import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';

/// A class representing a worker that performs API requests and handles responses.
class Worker {
  late SendPort _mainThreadSendPort;
  late ReceivePort _workerReceivePort;
  late SendPort _workerSendPort;
  bool _isolateRunning = false;
  Timer? _apiRequestTimer;
  late StreamController<dynamic> _responseController;
  bool _isPhoneRinging = false;
  Completer<void> _apiCallCompleter = Completer<void>();

  // API URL for fetching random numbers.
  static const String _apiUrl = "https://csrng.net/csrng/csrng.php?min=0&max=1";
  // Interval for API requests.
  static const Duration _apiRequestInterval = Duration(seconds: 5);

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 5000),
      receiveTimeout: const Duration(milliseconds: 5000),
    ),
  );

  /// Constructor to initialize the worker with communication ports.
  Worker(this._workerReceivePort, this._mainThreadSendPort) {
    _responseController = StreamController<dynamic>.broadcast();
    _workerSendPort = _workerReceivePort.sendPort;
  }

  /// Initializes the worker and starts API requests.
  Future<void> initialize() async {
    _mainThreadSendPort.send('initialize');
    _startApiRequests();
  }

  /// Stream of API response data.
  Stream<dynamic> get responseStream => _responseController.stream;

  /// Starts periodic API requests.
  void _startApiRequests() {
    _isolateRunning = true;
    _apiRequestTimer = Timer.periodic(_apiRequestInterval, _requestApiData);
  }

  /// Requests data from the API at regular intervals.
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

  /// Simulates phone ringing by printing messages.
  Future<void> _ringPhone() async {
    for (var i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(seconds: 1), () {
        print("Phone Ringing $i times!");
      });
    }
  }

  /// Stops periodic API requests.
  void _stopApiRequests() {
    _isolateRunning = false;
    _apiRequestTimer?.cancel();
  }

  /// Initializes the worker isolate and communication ports.
  static Future<Worker> init() async {
    final receivePort = ReceivePort();
    Isolate.spawn(_startIsolate, receivePort.sendPort);
    final mainThreadSendPort = await receivePort.first;
    return Worker(receivePort, mainThreadSendPort);
  }

  /// Starts the worker isolate and initializes worker instance.
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

  /// Closes the worker and cleans up resources.
  void close() {
    if (_isolateRunning) {
      _workerSendPort.send('shutdown');
      _responseController.close();
    }
  }

  /// Fetches a random number from the API.
  static Future<int> _getNumber() async {
    Response response = await _dio.get(_apiUrl);
    print("API Response: ${response.data}");

    var random = response.data[0]['random'];

    return random;
  }
}
