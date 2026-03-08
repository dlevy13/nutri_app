import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile_form/profile_form_notifier.dart';
import '../profile_form/profile_form_state.dart';
import '../repositories/strava_repository.dart';
import 'legal_notice_page.dart';
import '../services/logout_service.dart';
import '../pages/confirm_email_page.dart';
import '../startup_gate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';


class ProfileFormPage extends ConsumerStatefulWidget {
  const ProfileFormPage({super.key});

  @override
  ConsumerState<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends ConsumerState<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = "";

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
      appBar: AppBar(title: const Text("Mon Profil")),
      body: state.status == FormStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [  
                    // ───── EMAIL (lecture seule) ─────
                    TextFormField(
                      initialValue: email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: "Adresse email",
                        helperText: "Email du compte (non modifiable)",
                      ),
                    ),
                  // ───── PRÉNOM ─────
                    TextFormField(
                      controller: _prenomCtrl,
                      decoration:
                          const InputDecoration(labelText: "Prénom"),
                      onChanged: (v) {
                        notifier.prenomChanged(v);
                        _scheduleAutosave(notifier);
                      },
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Champ obligatoire"
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // ───── DATE DE NAISSANCE ─────
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          locale: const Locale('fr', 'FR'),
                          initialDate: state.birthDate ?? DateTime(2000),
                          firstDate: DateTime(1920),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          notifier.birthDateChanged(picked);
                          _scheduleAutosave(notifier);
                        }
                      },
                      child: Text(
                        state.birthDate == null
                            ? "Sélectionner la date de naissance"
                            : "Date : ${DateFormat("dd/MM/yyyy").format(state.birthDate!)}",
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ───── SEXE ─────
                    DropdownButtonFormField<String>(
                      value: state.sexe,
                      decoration:
                          const InputDecoration(labelText: "Sexe"),
                      items: const ["Homme", "Femme"]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        notifier.sexeChanged(v);
                        _scheduleAutosave(notifier);
                      },
                    ),

                    const SizedBox(height: 16),

                    // ───── ACTIVITÉ ─────
                    DropdownButtonFormField<String>(
                      value: state.activite,
                      decoration: const InputDecoration(
                          labelText: "Niveau d'activité"),
                      items: const ["Sédentaire", "Modéré", "Actif", "Très actif"]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        notifier.activiteChanged(v);
                        _scheduleAutosave(notifier);
                      },
                    ),

                    const SizedBox(height: 16),

                    // ───── TAILLE ─────
                    TextFormField(
                      controller: _tailleCtrl,
                      decoration:
                          const InputDecoration(labelText: "Taille (cm)"),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        notifier.tailleChanged(v);
                        _scheduleAutosave(notifier);
                      },
                    ),

                    // ───── POIDS ─────
                    TextFormField(
                      controller: _poidsCtrl,
                      decoration:
                          const InputDecoration(labelText: "Poids (kg)"),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        notifier.poidsChanged(v);
                        _scheduleAutosave(notifier);
                      },
                    ),

                    const SizedBox(height: 16),

                    // ───── LIEN GARMIN ─────
                    // désactivé suite changement Garmin,
                    //la publication d'un calendrier ne permet plus le parsing
                    TextFormField(
                      controller: _garminCtrl,
                      decoration: const InputDecoration(
                        labelText: "Lien Garmin (optionnel)",
                        hintText: "https://connect.garmin.com/...",
                      ),
                      onChanged: (v) {
                        notifier.garminLinkChanged(v);
                        _scheduleAutosave(notifier);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            !uri.isAbsolute ||
                            !uri.host.contains('garmin.com')) {
                          return 'Lien Garmin invalide';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    // ───── AIDE GARMIN ─────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new),
                            label: const Text(
                              "Ouvrir Garmin pour copier le lien",
                            ),
                            onPressed: _openGarmin,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Garmin s’ouvrira dans votre navigateur.\n"
                            "Copiez le lien iCal puis revenez dans l’app.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ───── INDICATEUR AUTOSAVE ─────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isDirty
                          ? const Text(
                              "Modifications en cours…",
                              key: ValueKey('dirty'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            )
                          : _savedIndicatorVisible
                              ? Row(
                                  key: const ValueKey('saved'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check_circle,
                                        color: Colors.green, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      "Enregistré",
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 8),

                    // ───── ENREGISTRER ─────
                    ElevatedButton(
                      onPressed: state.status == FormStatus.loading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              
                              _autosaveTimer?.cancel();
                              
                              // On met à jour les flags locaux
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('has_profile', true);
                              await prefs.setBool('onboarding_done', true);

                              // On lance la sauvegarde. Le ref.listen s'occupera du reste.
                              await notifier.saveProfile();
                            },
                      child: state.status == FormStatus.loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Enregistrer"),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const Divider(),

                    Center(
                      child: TextButton.icon(
                        onPressed: () => logout(context),
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          "Se déconnecter",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),

                    // ───── STRAVA ─────
                    const _StravaConnectSection(),

                    // ───── MENTIONS LÉGALES ─────
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalNoticePage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Consulter les mentions légales",
                          style: TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
          "🔗 Connexion Strava",
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
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text("Compte Strava connecté"),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: notifier.disconnectStrava,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                backgroundColor: const Color(0xFFFC4C02),
                foregroundColor: Colors.white,
              ),
            );
          },
        ),
      ],
    );
  }
}
