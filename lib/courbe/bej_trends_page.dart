import 'package:flutter/material.dart';
import 'bej_chart.dart'; // ← contient le widget BejChart
import 'macro_chart.dart';

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
            ],
          ),
        ),
      ),
    );
  }
}
