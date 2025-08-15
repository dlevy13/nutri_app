

import 'package:flutter/material.dart';

extension ColorValues on Color {
  /// Crée une nouvelle couleur en remplaçant sélectivement la valeur alpha.
  /// La valeur alpha est un entier entre 0 (transparent) et 255 (opaque).
  Color withValues({required int alpha}) {
    return withAlpha(alpha);
  }
}