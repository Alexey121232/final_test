import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sheetsService = GoogleSheetsService();
  await sheetsService.init();
  runApp(MyApp(sheetsService: sheetsService));
}

class GoogleSheetsService {
  final _credentialsPath = 'assets/credentials.json';
  final _spreadsheetId = '1K793prQUYWwSlBHDRYOB-O6h2_wnd4_mOTObN0qKIX4';
  late GSheets _gsheets;
  Worksheet? _userSheet;
  Worksheet? _historySheet;

  Future<void> init() async {
    final credentials = await rootBundle.loadString(_credentialsPath);
    final jsonCredentials = jsonDecode(credentials);
    _gsheets = GSheets(jsonCredentials);
    final spreadsheet = await _gsheets.spreadsheet(_spreadsheetId);
    _userSheet = spreadsheet.worksheetByTitle('users');
    _historySheet = spreadsheet.worksheetByTitle('history');

    if (_userSheet == null || _historySheet == null) {
      throw Exception('Не найдены листы "users" или "history". Убедитесь, что они есть в таблице.');
    }
  }

  Future<List<Map<String, String>>> getUsers() async {
    return await _userSheet!.values.map.allRows() ?? [];
  }

  Future<void> addUser(String username, String password, String role) async {
    await _userSheet!.values.appendRow([username, password, role]);
  }

  Future<void> logHistory(String userId, String action) async {
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    await _historySheet!.values.appendRow([userId, action, now]);
  }
}

class MyApp extends StatelessWidget {
  final GoogleSheetsService sheetsService;
  MyApp({required this.sheetsService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Connect',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: LoginScreen(sheetsService: sheetsService),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final GoogleSheetsService sheetsService;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginScreen({required this.sheetsService});

  void login(BuildContext context) async {
    final users = await sheetsService.getUsers();
    final user = users.firstWhere(
      (u) => u['username'] == usernameController.text && u['password'] == passwordController.text,
      orElse: () => {},
    );

    if (user.isNotEmpty) {
      final userId = users.indexOf(user).toString();
      await sheetsService.logHistory(userId, 'Login');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(role: user['role']!, userId: userId, sheetsService: sheetsService),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Неверные данные')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Вход в School Connect', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 20),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(labelText: 'Логин'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: 'Пароль'),
                  obscureText: true,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => login(context),
                  child: Text('Войти'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String role;
  final String userId;
  final GoogleSheetsService sheetsService;
  HomeScreen({required this.role, required this.userId, required this.sheetsService});

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case 'teacher':
        return PlaceholderScreen(title: 'Учитель');
      case 'social_worker':
        return PlaceholderScreen(title: 'Социальный педагог');
      case 'admin':
      case 'super_admin':
        return AdminPanelScreen(sheetsService: sheetsService, role: role);
      case 'principal':
        return PlaceholderScreen(title: 'Директор школы');
      case 'deputy_schedule':
        return PlaceholderScreen(title: 'Завуч по расписанию');
      case 'deputy_nutrition':
        return PlaceholderScreen(title: 'Завуч по питанию');
      case 'deputy_education':
        return PlaceholderScreen(title: 'Завуч по воспитательной работе');
      case 'system_admin':
        return PlaceholderScreen(title: 'Системный администратор');
      default:
        return Scaffold(body: Center(child: Text('Неизвестная роль: $role')));
    }
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Добро пожаловать, $title')),
    );
  }
}

class AdminPanelScreen extends StatefulWidget {
  final GoogleSheetsService sheetsService;
  final String role;
  AdminPanelScreen({required this.sheetsService, required this.role});

  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String selectedRole = 'teacher';

  bool canManageUsers(String role) {
    return role == 'admin' || role == 'super_admin';
  }

  Future<void> createUser() async {
    await widget.sheetsService.addUser(usernameController.text, passwordController.text, selectedRole);
    setState(() {});
  }

  Future<List<Map<String, String>>> fetchUsers() async {
    return await widget.sheetsService.getUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (!canManageUsers(widget.role)) {
      return Scaffold(
        appBar: AppBar(title: Text('Доступ запрещён')),
        body: Center(child: Text('У вас нет прав доступа к этой панели.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Панель администратора')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Логин'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Пароль'),
            ),
            DropdownButton<String>(
              value: selectedRole,
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedRole = value);
                }
              },
              items: [
                'teacher',
                'social_worker',
                'admin',
                'principal',
                'deputy_schedule',
                'deputy_nutrition',
                'deputy_education',
                'super_admin',
                'system_admin',
              ].map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
            ),
            ElevatedButton(
              onPressed: createUser,
              child: Text('Создать аккаунт'),
            ),
            Expanded(
              child: FutureBuilder(
                future: fetchUsers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final users = snapshot.data as List<Map<String, String>>;
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        title: Text(user['username'] ?? ''),
                        subtitle: Text('Роль: ${user['role'] ?? ''}'),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
