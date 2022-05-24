// You have generated a new plugin project without
// specifying the `--platforms` flag. A plugin project supports no platforms is generated.
// To add platforms, run `flutter create -t plugin --platforms <platforms> .` under the same
// directory. You can also find a detailed instruction on how to add platforms in the `pubspec.yaml` at https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:path_provider/path_provider.dart';

class FoodbAdminApp extends StatefulWidget {
  FoodbAdminApp({Key? key}) : super(key: key);

  @override
  State<FoodbAdminApp> createState() => _FoodbAdminAppState();
}

class FoodbAdapterOption {
  String label;
  Function onInit;
  List<Widget> configs;
  FoodbAdapterOption(
      {required this.label, required this.onInit, this.configs = const []});
}

class _FoodbAdminAppState extends State<FoodbAdminApp> {
  FoodbAdapterOption? selectedAdapter;
  String? selectedFolder;
  List<FoodbAdapterOption> adapters = [
    FoodbAdapterOption(
        label: 'Object Box',
        configs: [
          ElevatedButton(
            onPressed: () async => {
    selectedFolder = await FilesystemPicker.open(
      rootDirectory: await getApplicationDocumentsDirectory(),
      title: 'Open database folder',
      context: context,
      fsType: FilesystemType.folder,
      pickText: 'Open database from this folder',
      folderIconColor: Colors.teal,
    )
  },
            child: Text('Select Folder'),
          )
        ],
        onInit: () async {
          var store = await openStore();
          return ObjectBoxAdapter(store);
        })
  ];

  _FoodbAdminAppState();

  @override
  void initState() {
    super.initState();
  }

  updateDbDirectory() 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Text('Foodb Admin'),
            ),
            DropdownButton<FoodbAdapterOption>(
              value: selectedAdapter,
              onChanged: (a) => setState(() {
                selectedAdapter = a;
              }),
              items: adapters
                  .map((e) => DropdownMenuItem(
                        child: Text(e.label),
                        value: e,
                      ))
                  .toList(),
            ),
            if (selectedAdapter != null) ...selectedAdapter!.configs
          ],
        ),
      ),
    );
  }
}
