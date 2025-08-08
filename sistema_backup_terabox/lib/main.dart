import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database.dart';
import 'services/password_manager.dart';
import 'viewmodels/backup_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/history_viewmodel.dart';
import 'views/home_page.dart';
import 'views/search_page.dart';
import 'views/history_page.dart';
import 'views/settings_page.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Backup Terabox',
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late AppDatabase _database;
  late PasswordManager _passwordManager;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  void _initializeSystem() {
    _database = AppDatabase();
    _passwordManager = PasswordManager(_database);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: _database),
        Provider<PasswordManager>.value(value: _passwordManager),
        ChangeNotifierProvider(
          create: (context) => BackupViewModel(_database, _passwordManager),
        ),
        ChangeNotifierProvider(
          create: (context) => SearchViewModel(_database, _passwordManager),
        ),
        ChangeNotifierProvider(
          create: (context) => HistoryViewModel(_database, _passwordManager),
        ),
      ],
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HomePage(),
            SearchPage(),
            HistoryPage(),
            SettingsPage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Buscar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Histórico',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }
}