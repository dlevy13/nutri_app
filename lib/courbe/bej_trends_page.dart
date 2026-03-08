import 'package:flutter/material.dart';
import 'bej_chart.dart'; // ← contient le widget BejChart
import 'macro_chart.dart';
import 'unsaturated_ratio_chart.dart';
import '../pages/profile_form_page.dart';

class BejTrendsPage extends StatelessWidget {
  const BejTrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tendances énergie & macros")),
      body: const Padding(
        padding: EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) CaloMètre (BEJ) — ta courbe existante
              BejChart(),
              SizedBox(height: 16),

              // 2) % Macros (MM5 sur les grammes P/G/L → % du total des macros)
              MacroPctSmaChart(),
              SizedBox(height: 16),
              // 3) Ratio Insaturés/Saturés (MM5)
              UnsaturatedRatioChart(),
              SizedBox(height: 16),

            ],
          ),
        ),
      ),
       bottomNavigationBar: _BottomNavBar(
        currentIndex: 0,
        onTap: (i) {
          switch (i) {
            case 0: break;
            case 1:
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BejTrendsPage()));
              break;
            case 2:
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFormPage()));
              break;
          }
        },
      ),
    );
  }
  
}
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        child: NavigationBar(
          height: 64,
          selectedIndex: currentIndex,
          onDestinationSelected: (i) {
            switch (i) {
              case 0: // Accueil
                Navigator.popUntil(context, (route) => route.isFirst);
                break;
              case 2: // Profil
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFormPage()));
                break;
            }
          },
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x114B49D1),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
