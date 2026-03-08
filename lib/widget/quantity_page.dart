
import 'package:flutter/material.dart';

// Classe de modèle pour les unités usuelles
class UsualUnit {
  final String label;        // ex. "morceau", "tranche", "càs"
  final double gramsPerUnit; // ex. 12.0
  const UsualUnit({required this.label, required this.gramsPerUnit});
}

// La page de sélection de quantité, maintenant dans son propre fichier
class QuantityPage extends StatefulWidget {
  const QuantityPage({
    super.key,
    required this.title,
    required this.unite,
    required this.defaultValue,
    this.usualUnits = const [],
    this.initialUnitIndex = 0,
  });

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
  final FocusNode _focus = FocusNode(); 
  double _value = 0;
  int _unitIndex = 0;
  bool _isEmpty = false;

  bool get _hasUsualUnits => widget.usualUnits.isNotEmpty;
  UsualUnit get _unit => widget.usualUnits[_unitIndex];
  double get _gramsPerUnit => _hasUsualUnits ? _unit.gramsPerUnit : 1.0;

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
    _controller = TextEditingController(text: _fmt(_value));
    final maxIndex = widget.usualUnits.isNotEmpty ? widget.usualUnits.length - 1 : 0;
    _unitIndex = _hasUsualUnits
        ? widget.initialUnitIndex.clamp(0, maxIndex)
        : 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  double? _tryParse(String s) {               
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _setValue(double v) {
    setState(() {
      _value = v.clamp(0, 999999);
      final t = _fmt(_value);
      _controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
      _isEmpty = false; 
    });
  }

  void _nudgeGeneric(double step) {
    if (_hasUsualUnits) {
      _setValue(_value + step * _gramsPerUnit);
    } else {
      _setValue(_value + step);
    }
  }

  void _submit() => Navigator.of(context).pop(_value);

  // Dans la classe _QuantityPageState

  void _setHalfPortion() {
    if (!_hasUsualUnits) return;
    final halfWeight = _gramsPerUnit / 2.0;
    _setValue(halfWeight);
  }

  String get _foodName {
    final t = widget.title;
    if (t.contains("'")) {
      final parts = t.split("'");
      if (parts.length >= 2) return parts[1];
    }
    return t;
  }

  List<double> _suggestions() {
    if (_hasUsualUnits) {
      const units = [1, 2, 3, 5];
      return units.map((u) => u * _gramsPerUnit).toList();
    }
    final base = <double>{widget.defaultValue, 50, 100, 150, 200};
    final list = base.where((e) => e > 0).toList()..sort();
    return list;
  }

  String _suggestionLabel(double grams) {
    if (_hasUsualUnits) {
      final u = (grams / _gramsPerUnit);
      final uInt = u.round();
      return "${_unit.label} x $uInt (~${_fmt(grams)} g)";
    }
    return "${_fmt(grams)} ${widget.unite}";
  }

  int get _currentUnits => _hasUsualUnits ? (_value / _gramsPerUnit).round() : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quantité"),
        actions: [
          TextButton(
            onPressed: _isEmpty ? null : _submit,
            child: const Text("OK"))
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _foodName,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 3,
                softWrap: true,
              ),
              const SizedBox(height: 8),

              if (_hasUsualUnits && widget.usualUnits.length > 1) ...[
                DropdownButton<int>(
                  value: _unitIndex,
                  items: List.generate(widget.usualUnits.length, (i) {
                    final u = widget.usualUnits[i];
                    return DropdownMenuItem<int>(
                      value: i,
                      child: Text("${u.label} (~${_fmt(u.gramsPerUnit)} g)"),
                    );
                  }),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _unitIndex = v);
                  },
                ),
                const SizedBox(height: 8),
              ],

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: cs.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Aligne les éléments sur l'axe principal
                    children: [
                      // --- MODIFICATION PRINCIPALE ICI ---
                      Expanded(
                        child: Row(
                          // 1. On centre le champ de texte et l'icône
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 2. On utilise IntrinsicWidth pour que la Row s'adapte à la taille du contenu
                            IntrinsicWidth(
                              child: Row(
                                mainAxisSize: MainAxisSize.min, // Le Row prend la taille minimale
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 3. Le TextField doit être flexible pour ne pas causer d'overflow
                                  Flexible(
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focus,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textInputAction: TextInputAction.done,
                                      autofocus: true,
                                      // 4. On aligne le texte à droite pour qu'il soit collé à l'icône
                                      textAlign: TextAlign.end, 
                                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.0),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        hintText: "",
                                      ),
                                      onChanged: (s) {
    // 1. On tente de convertir le texte en nombre
    final newValue = _tryParse(s);

    setState(() {
      if (newValue != null) {
        // 2. Si la conversion réussit, on met à jour la valeur
        //    principale (_value) et on s'assure que le champ n'est
        //    pas considéré comme vide.
        _value = newValue;
        _isEmpty = false;
      } else {
        // 3. Si le champ est vide ou contient un texte invalide
        //    (ex: "abc"), on le signale avec la variable _isEmpty
        //    pour désactiver les boutons de validation.
        _isEmpty = true;
      }
    });
  },
                                      onSubmitted: (_) {
                                        if (!_isEmpty) _submit();
                                      },
                                    ),
                                  ),
                                  // 5. L'icône se place juste après
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
                                    tooltip: "Modifier la quantité",
                                    onPressed: () => _focus.requestFocus(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Le texte de l'unité reste à sa place
                      if (_hasUsualUnits)
                        Text("≈ $_currentUnits ${_unit.label}${_currentUnits > 1 ? 's' : ''}",
                            style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant))
                      else
                        Text(widget.unite, style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (_hasUsualUnits) ...[
                Row(
                  children: [
                    _MiniBtn(label: "-1 ${_unit.label}", onTap: () => _nudgeGeneric(-1)),
                    const SizedBox(width: 6),
                    // ▼▼ LE NOUVEAU BOUTON ▼▼
                    _MiniBtn(label: "½ ${_unit.label}", onTap: _setHalfPortion),
                    const Spacer(),
                    _MiniBtn(label: "+1 ${_unit.label}", onTap: () => _nudgeGeneric(1), filled: true),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    _MiniBtn(label: "-10", onTap: () => _nudgeGeneric(-10)),
                    const SizedBox(width: 6),
                    _MiniBtn(label: "-1", onTap: () => _nudgeGeneric(-1)),
                    const Spacer(),
                    _MiniBtn(label: "+1", onTap: () => _nudgeGeneric(1), filled: true),
                    const SizedBox(width: 6),
                    _MiniBtn(label: "+10", onTap: () => _nudgeGeneric(10), filled: true),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestions().map((grams) {
                  final selected = (_value - grams).abs() < 0.0001;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(_suggestionLabel(grams)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => _setValue(grams),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(color: selected ? cs.onPrimaryContainer : null, fontSize: 12),
                  );
                }).toList(),
              ),

              const Spacer(),

              SafeArea(
                top: false,
                child: FilledButton(
                  onPressed: _isEmpty ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _hasUsualUnits
                        ? "Ajouter ~$_currentUnits ${_unit.label}${_currentUnits > 1 ? 's' : ''} (${_fmt(_value)} g)"
                        : "Ajouter ${_fmt(_value)} ${widget.unite}",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bouton compact (Outlined / Tonal)
class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _MiniBtn({required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    if (filled) {
      return FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: shape),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: shape,
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Text(label),
    );
  }
}