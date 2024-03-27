import 'package:shared_preferences/shared_preferences.dart';

import 'worker.dart';

/// A service class that manages the Worker instance and history of events.
class WorkerService {
  late Worker _worker;
  List<String> _history = [];

  /// Getter for accessing the history of events.
  List<String> get history => _history;

  /// Constructor that initializes the Worker and loads the history.
  WorkerService() {
    _initWorker();
    _loadHistory();
  }

  /// Initializes the Worker instance and sets up event handling.
  Future<void> _initWorker() async {
    try {
      _worker = await Worker.init();
      _worker.initialize();
      _worker.responseStream.listen(_handleWorkerResponse);
    } catch (e) {
      print("Error initializing worker: $e");
      // Handle the error (e.g., show a message to the user)
    }
  }

  /// Loads the history of events from SharedPreferences.
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _history = prefs.getStringList('history') ?? [];
  }

  /// Handles responses from the Worker and adds events to history.
  void _handleWorkerResponse(dynamic response) {
    if (response is int) {
      _addToHistory('Received number from API: $response');
    } else if (response is String) {
      _addToHistory(response);
    }
  }

  /// Adds an event to the history and saves it in SharedPreferences.
  void _addToHistory(String event) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toString();
    final historyEntry = '$timestamp: $event';

    _history.add(historyEntry);
    prefs.setStringList('history', _history);
  }

  /// Closes the Worker instance when no longer needed.
  void close() {
    _worker.close();
  }

  /// Getter for accessing the response stream from the Worker.
  Stream get responseStream => _worker.responseStream;
}
