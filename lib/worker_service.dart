import 'package:shared_preferences/shared_preferences.dart';

import 'worker.dart';

class WorkerService {
  late Worker _worker;
  List<String> _history = [];

  List<String> get history => _history;

  WorkerService() {
    _initWorker();
    _loadHistory();
  }

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

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _history = prefs.getStringList('history') ?? [];
  }

  void _handleWorkerResponse(dynamic response) {
    if (response is int) {
      _addToHistory('Received number from API: $response');
    } else if (response is String) {
      _addToHistory(response);
    }
  }

  void _addToHistory(String event) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toString();
    final historyEntry = '$timestamp: $event';

    _history.add(historyEntry);
    prefs.setStringList('history', _history);
  }

  void close() {
    _worker.close();
  }

  Stream get responseStream => _worker.responseStream;
}
