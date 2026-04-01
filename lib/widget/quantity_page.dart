import 'package:flutter/material.dart';
import 'card_shell.dart';

class UsualUnit {
  final String label;
  final double gramsPerUnit;
  const UsualUnit({required this.label, required this.gramsPerUnit});
}

class QuantityPage extends StatefulWidget {
  const QuantityPage(
      {super.key,
      required this.title,
      required this.unite,
      required this.defaultValue,
      this.usualUnits = const [],
      this.initialUnitIndex = 0});
  final String title;
  final String unite;
  final double defaultValue;
  final List<UsualUnit> usualUnits;
  final int initialUnitIndex;
  @override
  State<QuantityPage> createState() => _QuantityPageState();
}

class _QuantityPageState extends State<QuantityPage> {
  late final TextEditingController _controller;
  late double _value;
  late int _unitIndex;
  bool _valid = true;
  bool get _hasUnits => widget.usualUnits.isNotEmpty;
  UsualUnit get _unit => widget.usualUnits[_unitIndex];
  double get _step => _hasUnits ? _unit.gramsPerUnit : 1;
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
    _valid = _value.isFinite && _value > 0 && _value <= 999999;
    _unitIndex = _hasUnits
        ? widget.initialUnitIndex.clamp(0, widget.usualUnits.length - 1)
        : 0;
    _controller = TextEditingController(text: _fmt(_value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setValue(double value) {
    setState(() {
      _value = value.clamp(0, 999999);
      _valid = _value > 0;
      _controller.text = _fmt(_value);
    });
  }

  void _submit() {
    if (_valid) Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final firstQuote = widget.title.indexOf("'");
    final lastQuote = widget.title.lastIndexOf("'");
    final name = firstQuote >= 0 && lastQuote > firstQuote
        ? widget.title.substring(firstQuote + 1, lastQuote)
        : widget.title;
    final suggestions = _hasUnits
        ? [1, 2, 3, 5].map((n) => n * _step).toList()
        : (<double>{widget.defaultValue, 50, 100, 150, 200}
            .where((n) => n > 0)
            .toList()
          ..sort());
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir la quantité')),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    Text(name, style: text.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Ajuste la quantité avant de l’ajouter à ton repas.',
                        style: text.bodyLarge),
                    const SizedBox(height: 24),
                    CardShell(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          TextField(
                            controller: _controller,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: TextInputAction.done,
                            style: text.headlineLarge,
                            decoration: InputDecoration(
                                labelText: 'Quantité',
                                suffixText: widget.unite,
                                errorText: _valid
                                    ? null
                                    : 'Saisis une quantité positive (max. 999999).'),
                            onChanged: (s) => setState(() {
                              final value = double.tryParse(
                                  s.trim().replaceAll(',', '.'));
                              _valid = value != null &&
                                  value.isFinite &&
                                  value > 0 &&
                                  value <= 999999;
                              if (_valid) _value = value!;
                            }),
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_hasUnits) ...[
                            const SizedBox(height: 16),
                            if (widget.usualUnits.length > 1)
                              DropdownButtonFormField<int>(
                                initialValue: _unitIndex,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Portion usuelle'),
                                items: List.generate(
                                    widget.usualUnits.length,
                                    (i) => DropdownMenuItem(
                                        value: i,
                                        child: Text(
                                            '${widget.usualUnits[i].label} (~${_fmt(widget.usualUnits[i].gramsPerUnit)} g)',
                                            overflow: TextOverflow.ellipsis))),
                                onChanged: (i) {
                                  if (i != null) setState(() => _unitIndex = i);
                                },
                              ),
                            const SizedBox(height: 12),
                            Text(
                                'Équivalent : ${_fmt(_value / _step)} ${_unit.label} (~${_fmt(_value)} g)',
                                style: text.bodyMedium),
                          ],
                          const SizedBox(height: 16),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton(
                                onPressed: () => _setValue(
                                    _value - (_hasUnits ? _step : 10)),
                                child: Text(
                                    _hasUnits ? '− 1 ${_unit.label}' : '− 10')),
                            if (_hasUnits)
                              OutlinedButton(
                                  onPressed: () => _setValue(_step / 2),
                                  child: const Text('½ portion'))
                            else ...[
                              OutlinedButton(
                                  onPressed: () => _setValue(_value - 1),
                                  child: const Text('− 1')),
                              FilledButton.tonal(
                                  onPressed: () => _setValue(_value + 1),
                                  child: const Text('+ 1')),
                            ],
                            FilledButton.tonal(
                                onPressed: () => _setValue(
                                    _value + (_hasUnits ? _step : 10)),
                                child: Text(
                                    _hasUnits ? '+ 1 ${_unit.label}' : '+ 10')),
                          ]),
                        ])),
                    const SizedBox(height: 24),
                    Text('Quantités rapides', style: text.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: suggestions
                            .map((grams) => ChoiceChip(
                                  selected:
                                      _valid && (_value - grams).abs() < 0.0001,
                                  label: Text(_hasUnits
                                      ? '${_fmt(grams / _step)} ${_unit.label} · ${_fmt(grams)} g'
                                      : '${_fmt(grams)} ${widget.unite}'),
                                  onSelected: (_) => _setValue(grams),
                                ))
                            .toList()),
                  ]),
                ))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _valid ? _submit : null,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                            _valid
                                ? 'Ajouter ${_fmt(_value)} ${widget.unite}'
                                : 'Ajouter au repas',
                            textAlign: TextAlign.center),
                      )))),
        ),
      ])),
    );
  }
}
