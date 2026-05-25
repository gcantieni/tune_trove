import 'package:flutter/material.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

class RecorderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Record'),
      ),
      body: const Center(child: Text("Recorder Page")),
    );
  }
}
