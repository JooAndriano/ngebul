import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'widgets/buy_mode_toggle.dart';
import 'widgets/debug_panel.dart';
import 'widgets/employee_list.dart';
import 'widgets/menu_list.dart';
import 'widgets/tap_area.dart';
import 'widgets/top_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TopBar(),
              const Expanded(flex: 5, child: TapArea()),
              if (kDebugMode) const DebugPanel(),
              const TabBar(
                tabs: [
                  Tab(text: 'Menu'),
                  Tab(text: 'Karyawan'),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: BuyModeToggle(),
              ),
              const Expanded(
                flex: 6,
                child: TabBarView(
                  children: [MenuList(), EmployeeList()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
