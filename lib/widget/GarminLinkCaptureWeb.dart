// lib/widget/GarminLinkCaptureWeb.dart
//
// Widget Web/PWA pour capter un lien calendrier Garmin (ou .ics).
// - iPhone (PWA standalone) : ouvre Garmin dans le MÊME onglet (window._top)
// - Bouton "Coller depuis le presse-papiers" caché sur iOS Web (coller manuel recommandé)
// - Bouton "Ouvrir dans Calendrier iOS" (webcal://) après détection d’un lien valide
//

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData; // pour _pasteFromClipboard
import 'package:web/web.dart' as web; 
class GarminLinkCaptureWeb extends StatefulWidget {
  const GarminLinkCaptureWeb({
    super.key,
    this.onLinkDetected,
    this.initialValue,
    this.restrictToGarmin = false,
    this.autofocusField = false,
  });

  final ValueChanged<String>? onLinkDetected;
  final String? initialValue;
  final bool restrictToGarmin;
  final bool autofocusField;

  @override
  State<GarminLinkCaptureWeb> createState() => _GarminLinkCaptureWebState();
}

class _GarminLinkCaptureWebState extends State<GarminLinkCaptureWeb> {
  static const _garminCalendarUrl = 'https://connect.garmin.com/modern/calendar';

  final _ctrl = TextEditingController();
  String? _error;
  bool _checking = false;
  bool _isValid = false;
  bool _sent = false; // évite les doublons

  bool get _isIosWeb {
    if (!kIsWeb) return false;
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  }

  // .ics ou URL contenant "calendar"/"ical"
  final RegExp _icsRegex = RegExp(
    r'^(https?:\/\/[^\s"]+\.ics(?:\?[^\s"]*)?|https?:\/\/[^\s"]*(?:calendar|ical)[^\s"]*)$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    final init = widget.initialValue?.trim();
    if (init != null && init.isNotEmpty) {
      _ctrl.text = init;
      _isValid = _validate(_ctrl.text, silent: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openGarmin() {
    try {
      if (_isIosWeb) {
        web.window.open(_garminCalendarUrl, '_top'); // iOS PWA
      } else {
        web.window.open(_garminCalendarUrl, '_blank'); // nouvel onglet
      }
    } catch (_) {
      web.window.location.href = _garminCalendarUrl; // fallback
    }
  }

  bool _validate(String text, {bool silent = false}) {
    final value = text.trim();
    if (value.isEmpty) {
      if (!silent) setState(() => _error = "Colle ici un lien iCal (.ics) ou ton lien Garmin.");
      return false;
    }

    final uri = Uri.tryParse(value);
    final looksUrl = uri != null &&
        (uri.isScheme("http") || uri.isScheme("https")) &&
        uri.host.isNotEmpty;

    final matchesIcs = _icsRegex.hasMatch(value);
    final isGarminHost = looksUrl && uri!.host.toLowerCase().contains('garmin.com');

    if (!looksUrl || (!matchesIcs && !isGarminHost)) {
      if (!silent) setState(() => _error = "Format invalide : attends un lien .ics ou Garmin Connect.");
      return false;
    }

    if (widget.restrictToGarmin && !isGarminHost) {
      if (!silent) setState(() => _error = "Lien non-Garmin refusé (restriction activée).");
      return false;
    }

    if (!silent) setState(() => _error = null);
    return true;
  }

  void _accept(String url) {
    if (_sent) return;
    final clean = url.trim();
    _ctrl.text = clean;

    _isValid = _validate(clean, silent: false);
    if (!_isValid) {
      setState(() {}); // affiche l’erreur
      return;
    }

    _sent = true;
    widget.onLinkDetected?.call(clean);
  }

  Future<void> _pasteFromClipboard() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        setState(() => _error = "Presse-papiers vide. Copie le lien dans Garmin, puis réessaie.");
      } else if (!_validate(text, silent: false)) {
        // _validate a mis à jour _error
      } else {
        _accept(text);
      }
    } catch (_) {
      setState(() => _error = "Permission refusée. Colle le lien dans le champ ci-dessous.");
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _validateManual() {
    final text = _ctrl.text;
    if (_validate(text)) {
      _accept(text);
    }
  }

  void _openInIosCalendar() {
    final url = _ctrl.text.trim();
    if (!_validate(url, silent: false)) {
      setState(() {}); // affiche l’erreur
      return;
    }
    final webcal = url.replaceFirst(RegExp(r'^https?'), 'webcal');
    web.window.location.href = webcal; // iOS ouvre l’app Calendrier
  }

  @override
  Widget build(BuildContext context) {
    final helpGarminOnly = widget.restrictToGarmin
        ? "Seuls les liens Garmin sont acceptés."
        : "Accepte les liens Garmin et les flux iCal (.ics).";

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            "🔗 Connecter mon calendrier Garmin",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "1) Ouvre Garmin Connect → Calendrier → « Publier / Partager » et copie le lien iCal.\n"
            "2) Reviens ici et colle le lien (bouton ou manuel).",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _openGarmin,
                icon: const Icon(Icons.open_in_new),
                label: Text(_isIosWeb ? "Ouvrir Garmin (même onglet)" : "Ouvrir Garmin"),
              ),
              if (!_isIosWeb)
                ElevatedButton.icon(
                  onPressed: _checking ? null : _pasteFromClipboard,
                  icon: _checking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.paste),
                  label: const Text("Coller depuis le presse-papiers"),
                ),
              if (_isIosWeb)
                const Text(
                  "iPhone/iPad : appui long dans le champ ci-dessous pour « Coller ».",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _ctrl,
            autofocus: widget.autofocusField || _isIosWeb,
            decoration: InputDecoration(
              hintText: "https://… .ics",
              labelText: "Coller le lien manuellement",
              border: const OutlineInputBorder(),
              errorText: _error,
              suffixIcon: _isValid
                  ? const Icon(Icons.verified, color: Colors.green)
                  : IconButton(
                      tooltip: "Valider",
                      icon: const Icon(Icons.check),
                      onPressed: _validateManual,
                    ),
            ),
            onSubmitted: (_) => _validateManual(),
            onChanged: (v) {
              final wasValid = _isValid;
              _isValid = _validate(v, silent: true);
              if (wasValid != _isValid) setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Text(helpGarminOnly, style: const TextStyle(fontSize: 12, color: Colors.grey)),

          if (_isIosWeb && _isValid) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _openInIosCalendar,
              icon: const Icon(Icons.calendar_month),
              label: const Text("Ouvrir dans Calendrier iOS"),
            ),
          ],
        ]),
      ),
    );
  }
}
