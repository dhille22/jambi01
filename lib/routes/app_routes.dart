import 'package:flutter/material.dart';

import '../views/dashboard_page.dart';
import '../views/home_shell.dart';
import '../views/login_page.dart';
import '../views/register_page.dart';
import '../views/report_history_page.dart';
import '../views/report_page.dart';
import '../views/statistics_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const dashboard = '/dashboard';
  static const report = '/report';
  static const history = '/history';
  static const statistics = '/statistics';

  static Map<String, WidgetBuilder> get routes => {
    login: (_) => const LoginPage(),
    register: (_) => const RegisterPage(),
    home: (_) => const HomeShell(),
    dashboard: (_) => const DashboardPage(),
    report: (_) => const ReportPage(),
    history: (_) => const ReportHistoryPage(),
    statistics: (_) => const StatisticsPage(),
  };
}
