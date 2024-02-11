import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isolate_app/worker_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WorkerService _workerService;
  String _result = '';
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();
    _workerService = WorkerService();
  }

  @override
  void dispose() {
    _workerService.close();
    super.dispose();
  }

  void _startBlinking() {
    setState(() {
      _isBlinking = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isBlinking = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Worker App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _isBlinking ? Colors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(50),
              ),
              duration: Duration(milliseconds: 500),
              child: Center(
                child: StreamBuilder(
                  stream: _workerService.responseStream,
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.hasData ? snapshot.data.toString() : _result,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 20),
            Text('History:'),
            Expanded(
              child: StreamBuilder(
                stream: _workerService.responseStream,
                builder: (context, snapshot) {
                  return ListView.builder(
                    itemCount: _workerService.history.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_workerService.history[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
