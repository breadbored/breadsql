import 'dart:convert';

import 'package:adaptive_scrollbar/adaptive_scrollbar.dart';
import 'package:bread_sql/utils/dbUriParser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:highlight/languages/sql.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreadSQL Alpha 0.0.1 by @breadcodes',
      theme: ThemeData.dark(),
      home: const MyHomePage(title: 'BreadSQL Alpha'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Map<String, BreadDatabaseInfo> _databases = {};
  MySQLConnectionPool? pool;
  String viewName = "SelectDatabaseView";
  dynamic currentView;
  dynamic fab;
  dynamic barIcon;
  final _rawQueryController =
      TextEditingController(text: 'SELECT * FROM users LIMIT 100;');
  IResultSet? _queryResult;
  final _dataTableVerticalScrollController = ScrollController();
  final _dataTableHorizontalScrollController = ScrollController();

  @override
  void initState() {
    _getSavedDatabases();
    super.initState();
  }

  void _getCurrentView(BuildContext context) {
    switch (viewName) {
      case "SelectDatabaseView":
        currentView = SelectDatabaseView(
            databases: _databases,
            deleteDatabase: _deleteDatabase,
            connectToDatabase: _connectToDatabase);
        fab = SelectDatabaseFab(
          openCreateDatabaseView: _openCreateDatabaseView,
        );
        barIcon = IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            debugPrint('Refresh button pressed');
          },
          tooltip: 'Refresh List',
        );
        break;
      case "DatabaseView":
        currentView = Container(
            child: Column(children: [
          CodeEditor(),
          if (_queryResult != null && _queryResult!.isNotEmpty)
            Expanded(
                child: AdaptiveScrollbar(
                    controller: _dataTableVerticalScrollController,
                    underColor: Colors.blueGrey.withOpacity(0.3),
                    sliderDefaultColor: Colors.grey.withOpacity(0.7),
                    sliderActiveColor: Colors.grey,
                    child: AdaptiveScrollbar(
                        controller: _dataTableHorizontalScrollController,
                        position: ScrollbarPosition.bottom,
                        underColor: Colors.blueGrey.withOpacity(0.3),
                        sliderDefaultColor: Colors.grey.withOpacity(0.7),
                        sliderActiveColor: Colors.grey,
                        child: SingleChildScrollView(
                            controller: _dataTableHorizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                                controller: _dataTableVerticalScrollController,
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  border: TableBorder.all(),
                                  columns: [
                                    const DataColumn(label: Text("row")),
                                    for (var column
                                        in _queryResult?.cols.toList() ?? [])
                                      DataColumn(label: Text(column.name))
                                  ],
                                  rows: [
                                    for (var i = 0;
                                        i < _queryResult!.rows.length;
                                        i++)
                                      DataRow(
                                        cells: [
                                          DataCell(Text(i.toString())),
                                          for (var j = 0;
                                              j < _queryResult!.cols.length;
                                              j++)
                                            DataCell(Text(_queryResult!.rows
                                                .elementAt(i)
                                                .colAt(j)
                                                .toString()))
                                        ],
                                      ),
                                  ],
                                )))))),
        ]));
        fab = FloatingActionButton(
          onPressed: () {
            _queryDatabase(_rawQueryController.text, null).then((value) => {
                  setState(() {
                    _queryResult = value;
                  })
                });
          },
          tooltip: 'Run query',
          child: const Icon(Icons.play_arrow),
        );
        barIcon = IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            debugPrint('Back button pressed');
            setState(() {
              viewName = "SelectDatabaseView";
            });
          },
        );
        break;
      default:
        currentView = Container(
          child: const Center(
            child: Text('Error, go back to the Database selection view.'),
          ),
        );
        fab = null;
        barIcon = IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            debugPrint('Back button pressed');
            setState(() {
              viewName = "SelectDatabaseView";
            });
          },
        );
    }
  }

  Future<void> _connectToDatabase(BreadDatabaseInfo db) async {
    setState(() {
      pool = MySQLConnectionPool(
          host: db.host ?? 'localhost',
          port: int.parse(db.port ?? '3306'),
          userName: db.username ?? 'root',
          password: db.password,
          maxConnections: 10,
          databaseName: db.databaseName,
          secure: true);
      viewName = "DatabaseView";
    });
  }

  Future<void> _disconnectFromDatabase() async {
    if (pool != null) {
      await pool!.close();
      pool = null;
    }
  }

  Future<IResultSet> _queryDatabase(
      String query, Map<String, dynamic>? params) async {
    if (pool == null) {
      return Future.error('No database connection');
    }
    return await pool!.execute(query, params);
  }

  Future<void> _getSavedDatabases() async {
    final prefs = await SharedPreferences.getInstance();
    final databases = prefs.getKeys();
    setState(() {
      _databases.clear();
    });
    for (var database in databases) {
      final dbString = prefs.getString(database);
      final db = jsonDecode(dbString ?? '{}');
      final protocol_string = db['protocol'];
      SupportedProtocols protocol;
      switch (protocol_string) {
        case 'MYSQL':
          protocol = SupportedProtocols.MYSQL;
          break;
        default:
          protocol = SupportedProtocols.NIL;
      }
      final dbObj = BreadDatabaseInfo(
        protocol: protocol,
        username: db['username'],
        password: db['password'],
        host: db['host'],
        port: db['port'],
        databaseName: db['databaseName'],
      );
      setState(() {
        _databases[database] = dbObj;
      });
    }
  }

  Future<void> _saveDatabase(String name, BreadDatabaseInfo db) async {
    final prefs = await SharedPreferences.getInstance();
    final dbString = jsonEncode({
      'protocol': db.protocol.name,
      'username': db.username,
      'password': db.password,
      'host': db.host,
      'port': db.port,
      'databaseName': db.databaseName,
    });
    await prefs.setString(name, dbString);
    await _getSavedDatabases();
  }

  Future<void> _deleteDatabase(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(name);
    await _getSavedDatabases();
  }

  void _openCreateDatabaseView() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateDatabaseDialog(
          saveDatabase: _saveDatabase,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _getCurrentView(context);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          leading: barIcon),
      body: currentView,
      floatingActionButton:
          fab, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class SelectDatabaseFab extends StatelessWidget {
  final void Function() openCreateDatabaseView;
  const SelectDatabaseFab({super.key, required this.openCreateDatabaseView});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: openCreateDatabaseView,
      tooltip: 'Add Database',
      child: const Icon(Icons.add),
    );
  }
}

class SelectDatabaseView extends StatelessWidget {
  final Map<String, BreadDatabaseInfo> databases;
  final Future<void> Function(String name) deleteDatabase;
  final Future<void> Function(BreadDatabaseInfo db) connectToDatabase;
  const SelectDatabaseView(
      {super.key,
      required this.databases,
      required this.deleteDatabase,
      required this.connectToDatabase});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListView.builder(
        itemCount: databases.length,
        itemBuilder: (BuildContext context, int index) {
          final key = databases.keys.elementAt(index);
          final value = databases[key];
          return ListTile(
            title: Text(key),
            subtitle: Text(value?.host ?? ''),
            onTap: () {
              debugPrint('Tapped on $key');
              if (databases[key] != null) {
                connectToDatabase(databases[key]!);
              }
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                deleteDatabase(key);
              },
            ),
          );
        },
      ),
    );
  }
}

class CreateDatabaseDialog extends StatelessWidget {
  final Future<void> Function(String name, BreadDatabaseInfo db) saveDatabase;
  CreateDatabaseDialog({super.key, required this.saveDatabase});

  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _databaseNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a new database'),
      content: Column(
        children: <Widget>[
          TextField(
            controller:
                _nameController, // Assign the text controller to the TextField
            decoration: const InputDecoration(
              labelText: 'Nickname',
            ),
            onChanged: (value) => _nameController.text = value,
          ),
          TextField(
            controller:
                _hostController, // Assign the text controller to the TextField
            decoration: const InputDecoration(
              labelText: 'Host',
            ),
            onChanged: (value) => _hostController.text = value,
          ),
          TextField(
            controller:
                _portController, // Assign the text controller to the TextField
            decoration: const InputDecoration(
              labelText: 'Port',
            ),
            onChanged: (value) => _portController.text = value,
          ),
          TextField(
            controller:
                _usernameController, // Assign the text controller to the TextField
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
            onChanged: (value) => _usernameController.text = value,
          ),
          TextField(
            controller:
                _passwordController, // Assign the text controller to the TextField
            decoration: const InputDecoration(
              labelText: 'Password',
            ),
            onChanged: (value) => _passwordController.text = value,
          ),
          TextField(
            controller:
                _databaseNameController, // Assign the text controller to the TextField
            decoration: const InputDecoration(
              labelText: 'Database',
            ),
            onChanged: (value) => _databaseNameController.text = value,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final db = BreadDatabaseInfo(
              protocol: SupportedProtocols.MYSQL,
              username: _usernameController.text,
              password: _passwordController.text,
              host: _hostController.text,
              port: _portController.text,
              databaseName: _databaseNameController.text,
            );
            saveDatabase(_nameController.text, db);
            Navigator.of(context).pop();
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class CodeEditor extends StatefulWidget {
  @override
  _CodeEditorState createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  CodeController? _codeController;

  @override
  void initState() {
    _codeController = CodeController(
      text: "SELECT * FROM users LIMIT 100;",
      language: sql,
    );
    super.initState();
  }

  @override
  void dispose() {
    _codeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _codeController != null
        ? CodeTheme(
            data: CodeThemeData(styles: monokaiSublimeTheme),
            child: SingleChildScrollView(
                child: CodeField(
              controller: _codeController!,
              textStyle: const TextStyle(
                  fontFamily: 'SF Mono',
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600),
              gutterStyle: const GutterStyle(
                  textStyle: TextStyle(
                      fontFamily: 'SF Mono',
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600)),
            )))
        : const Text("Loading Code Field");
  }
}
