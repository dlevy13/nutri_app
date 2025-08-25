import 'package:flutter/material.dart';

class FoodSearchField extends StatefulWidget {
  final TextEditingController controller;      // fourni par le parent
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const FoodSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<FoodSearchField> createState() => _FoodSearchFieldState();
}

class _FoodSearchFieldState extends State<FoodSearchField> {
  void _onTextChanged() {
    if (!mounted) return; // évite setState après dispose
    setState(() {});      // juste pour afficher/masquer la croix
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant FoodSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // si le parent change de controller, on rebranche proprement
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      if (mounted) setState(() {}); // rafraîchir l'UI si le texte diffère
    }
  }

  @override
  void dispose() {
    // très important : retirer le listener
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _clear() {
    // ne pas appeler setState ici : _onTextChanged sera déclenché par clear()
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        hintText: "Rechercher un aliment",
        border: const OutlineInputBorder(),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clear,
                tooltip: 'Effacer',
              )
            : null,
      ),
      onChanged: widget.onChanged, // tu gardes la logique métier côté parent
    );
  }
}
