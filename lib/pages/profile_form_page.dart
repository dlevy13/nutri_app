import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile_form/profile_form_notifier.dart';
import '../profile_form/profile_form_state.dart';
import '../repositories/strava_repository.dart';
import 'legal_notice_page.dart';
import '../services/logout_service.dart';
import '../pages/confirm_email_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'widgets/profile_content.dart';
import '../ui/theme/app_theme.dart';

class ProfileFormPage extends ConsumerStatefulWidget {
  const ProfileFormPage({super.key});

  @override
  ConsumerState<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends ConsumerState<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();

  Timer? _autosaveTimer;
  bool _isDirty = false;
  bool _savedIndicatorVisible = false;

  late final TextEditingController _prenomCtrl;
  late final TextEditingController _tailleCtrl;
  late final TextEditingController _poidsCtrl;
  late final TextEditingController _garminCtrl;

  // Snapshot du dernier état sauvegardé (valeurs)
  Map<String, dynamic>? _lastSavedSnapshot;

  Map<String, dynamic> _snapshot(ProfileFormState s) => {
        'prenom': s.prenom,
        'taille': s.taille,
        'poids': s.poids,
        'sexe': s.sexe,
        'activite': s.activite,
        'garminLink': s.garminLink,
        'birthDate': s.birthDate?.millisecondsSinceEpoch,
      };

  bool _hasChanged(ProfileFormState s) {
    final current = _snapshot(s);
    return _lastSavedSnapshot == null ||
        !mapEquals(current, _lastSavedSnapshot);
  }

  void _scheduleAutosave(ProfileFormNotifier notifier) {
    // On lit l'état à jour (après le notifier.xxxChanged)
    final latest = ref.read(profileFormProvider);

    if (latest.status == FormStatus.loading) return;

    if (!_hasChanged(latest)) {
      if (_isDirty) setState(() => _isDirty = false);
      return;
    }

    if (!_isDirty || _savedIndicatorVisible) {
      setState(() {
        _isDirty = true;
        _savedIndicatorVisible = false;
      });
    } else {
      _isDirty = true;
      _savedIndicatorVisible = false;
    }

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;

      final current = ref.read(profileFormProvider);
      if (current.status == FormStatus.loading) return;

      if (!_hasChanged(current)) {
        if (mounted) setState(() => _isDirty = false);
        return;
      }

      final valid = _formKey.currentState?.validate() ?? false;
      if (!valid) return;

      await notifier.saveProfile(autoSave: true);

      if (!mounted) return;

      final afterSave = ref.read(profileFormProvider);
      _lastSavedSnapshot = _snapshot(afterSave);

      setState(() {
        _isDirty = false;
        _savedIndicatorVisible = true;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _prenomCtrl = TextEditingController();
    _tailleCtrl = TextEditingController();
    _poidsCtrl = TextEditingController();
    _garminCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final state = ref.read(profileFormProvider);

      _prenomCtrl.text = state.prenom;
      _tailleCtrl.text = state.taille;
      _poidsCtrl.text = state.poids;
      _garminCtrl.text = state.garminLink;

      ref.read(profileFormProvider.notifier).loadLocalData();
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();

    _prenomCtrl.dispose();
    _tailleCtrl.dispose();
    _poidsCtrl.dispose();
    _garminCtrl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    final email = user?.email ?? "";

    // 🔒 EMAIL NON CONFIRMÉ → BLOCAGE
    if (session == null) {
      return const ConfirmEmailPage();
    }
    final state = ref.watch(profileFormProvider);
    if (_prenomCtrl.text != state.prenom) {
      _prenomCtrl.text = state.prenom;
    }
    if (_tailleCtrl.text != state.taille) {
      _tailleCtrl.text = state.taille;
    }
    if (_poidsCtrl.text != state.poids) {
      _poidsCtrl.text = state.poids;
    }
    if (_garminCtrl.text != state.garminLink) {
      _garminCtrl.text = state.garminLink;
    }

    final notifier = ref.read(profileFormProvider.notifier);

    // Init snapshot au premier "success"
    if (_lastSavedSnapshot == null && state.status == FormStatus.success) {
      _lastSavedSnapshot = _snapshot(state);
    }

    // Snackbars

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: state.status == FormStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : ProfileContent(
              state: state,
              email: email,
              formKey: _formKey,
              firstName: _prenomCtrl,
              height: _tailleCtrl,
              weight: _poidsCtrl,
              garmin: _garminCtrl,
              dirty: _isDirty,
              saved: _savedIndicatorVisible,
              strava: const _StravaConnectSection(),
              onTextChanged: (field, value) {
                switch (field) {
                  case ProfileField.firstName:
                    notifier.prenomChanged(value);
                  case ProfileField.height:
                    notifier.tailleChanged(value);
                  case ProfileField.weight:
                    notifier.poidsChanged(value);
                  case ProfileField.garmin:
                    notifier.garminLinkChanged(value);
                }
                _scheduleAutosave(notifier);
              },
              onSexChanged: (v) {
                notifier.sexeChanged(v);
                _scheduleAutosave(notifier);
              },
              onActivityChanged: (v) {
                notifier.activiteChanged(v);
                _scheduleAutosave(notifier);
              },
              onBirthDate: () async {
                final picked = await showDatePicker(
                    context: context,
                    locale: const Locale('fr', 'FR'),
                    initialDate: state.birthDate ?? DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now());
                if (!mounted || picked == null) return;
                notifier.birthDateChanged(picked);
                _scheduleAutosave(notifier);
              },
              onSave: () async {
                if (!_formKey.currentState!.validate()) return;
                _autosaveTimer?.cancel();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_profile', true);
                await prefs.setBool('onboarding_done', true);
                await notifier.saveProfile();
              },
              onOpenGarmin: _openGarmin,
              onLogout: () => logout(context),
              onLegal: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LegalNoticePage())),
            ),
    );
  }

  Future<void> _openGarmin() async {
    final uri = Uri.parse('https://connect.garmin.com/modern/calendar');

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’ouvrir Garmin")),
      );
    }
  }
}

/// ─────────────────────────────────────────────
/// 🔗 STRAVA CONNECTION — INCHANGÉE
/// ─────────────────────────────────────────────

class _StravaConnectSection extends ConsumerWidget {
  const _StravaConnectSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnectedAsync = ref.watch(isStravaConnectedProvider);
    final stravaService = ref.read(stravaServiceProvider);
    final notifier = ref.read(profileFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Strava",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        isConnectedAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text("Erreur lors de la connexion Strava"),
          data: (isConnected) {
            if (isConnected) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: AppColors.green),
                      SizedBox(width: 8),
                      Expanded(child: Text("Compte Strava connecté")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: notifier.disconnectStrava,
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                    child: const Text("Se déconnecter de Strava"),
                  ),
                ],
              );
            }

            return ElevatedButton.icon(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await stravaService.launchAuthUrl(uid);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez vous connecter d'abord."),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.link),
              label: const Text("Connecter mon compte Strava"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
            );
          },
        ),
      ],
    );
  }
}
