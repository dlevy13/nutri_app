// dans lib/pages/profile_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile_form/profile_form_notifier.dart';
import '../profile_form/profile_form_state.dart';
import '../repositories/strava_repository.dart';
import '../services/strava_service.dart';
import 'legal_notice_page.dart';

class ProfileFormPage extends ConsumerStatefulWidget {
  const ProfileFormPage({super.key});

  @override
  ConsumerState<ProfileFormPage> createState() => _ProfileFormPageState();
}

// dans la classe _ProfileFormPageState de votre fichier profile_form_page.dart

class _ProfileFormPageState extends ConsumerState<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Les controllers sont toujours nécessaires
  late TextEditingController _prenomController;
  late TextEditingController _poidsController;
  late TextEditingController _tailleController;
  late TextEditingController _stravaClientIdController;
  late TextEditingController _stravaClientSecretController;
  late TextEditingController _garminLinkController;

  @override
  void initState() {
    super.initState();
    _prenomController = TextEditingController();
    _poidsController = TextEditingController();
    _tailleController = TextEditingController();
    _stravaClientIdController = TextEditingController();
    _stravaClientSecretController = TextEditingController();
    _garminLinkController = TextEditingController();
    
    // On écoute l'état pour synchroniser les controllers une seule fois au chargement
    ref.listenManual(profileFormProvider, (previous, next) {
    // ✅ NOUVELLE CONDITION, PLUS SIMPLE ET ROBUSTE
    // Si l'état est un succès, on met à jour les champs.
    // Cela fonctionnera au premier chargement ET aux visites suivantes.
    if (next.status == FormStatus.success) {
      
      
      // On vérifie si le texte est différent avant de le modifier
      // pour éviter que le curseur ne saute si l'utilisateur est en train d'écrire.
      if (_prenomController.text != next.prenom) {
        _prenomController.text = next.prenom;
      }
      if (_poidsController.text != next.poids) {
        _poidsController.text = next.poids;
      }
      if (_tailleController.text != next.taille) {
        _tailleController.text = next.taille;
      }
      if (_stravaClientIdController.text != next.stravaClientId) {
        _stravaClientIdController.text = next.stravaClientId;
      }
      if (_stravaClientSecretController.text != next.stravaClientSecret) {
        _stravaClientSecretController.text = next.stravaClientSecret;
      }
      if (_garminLinkController.text != next.garminLink) {
        _garminLinkController.text = next.garminLink;
      }
    }
  }, fireImmediately: true);
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _poidsController.dispose();
    _tailleController.dispose();
    _stravaClientIdController.dispose();
    _stravaClientSecretController.dispose();
    _garminLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileFormProvider);
    final notifier = ref.read(profileFormProvider.notifier);
    
    // On écoute les changements d'état pour afficher les SnackBars
    ref.listen(profileFormProvider, (previous, next) {
      if (previous?.status == FormStatus.loading && next.status == FormStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Profil enregistré !"), backgroundColor: Colors.green),
        );
      }
      if (previous?.status == FormStatus.loading && next.status == FormStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Erreur lors de l'enregistrement."), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Profil')),
      body: state.status == FormStatus.loading && _prenomController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _prenomController,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      onChanged: (value) => notifier.prenomChanged(value),
                    ),
                    TextFormField(
                      controller: _poidsController,
                      decoration: const InputDecoration(labelText: 'Poids (kg)'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => notifier.poidsChanged(value),
                    ),
                    TextFormField(
                      controller: _tailleController,
                      decoration: const InputDecoration(labelText: 'Taille (cm)'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => notifier.tailleChanged(value),
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: state.birthDate ?? DateTime(2000),
                          firstDate: DateTime(1920),
                          lastDate: DateTime.now(),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (picked != null) {
                          notifier.birthDateChanged(picked);
                        }
                      },
                      child: Text(state.birthDate == null
                          ? "Sélectionner la date de naissance"
                          : "Date de naissance : ${DateFormat('dd/MM/yyyy').format(state.birthDate!)}"),
                    ),

                    DropdownButtonFormField<String>(
                      value: state.sexe,
                      decoration: const InputDecoration(labelText: 'Sexe'),
                      items: ['Homme', 'Femme'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (v) => v != null ? notifier.sexeChanged(v) : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: state.activite,
                      decoration: const InputDecoration(labelText: 'Niveau d\'activité'),
                      items: ['Sédentaire', 'Modéré', 'Actif', 'Très actif'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (v) => v != null ? notifier.activiteChanged(v) : null,
                    ),
                    TextFormField(
                      controller: _garminLinkController,
                      decoration: const InputDecoration(
                        labelText: 'Lien Garmin (optionnel)',
                        hintText: 'https://connect.garmin.com/...',
                      ),
                      onChanged: (value) => notifier.garminLinkChanged(value),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final uri = Uri.tryParse(value);
                        if (uri == null || !uri.isAbsolute || !uri.host.contains('garmin.com')) {
                          return 'Lien Garmin invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: state.status == FormStatus.loading ? null : () {
                        if (_formKey.currentState!.validate()) {
                          notifier.saveProfile();
                        }
                      },
                      child: state.status == FormStatus.loading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('Enregistrer le Profil'),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    Text("🔒 Identifiants Strava", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _stravaClientIdController,
                      decoration: const InputDecoration(labelText: "Client ID"),
                      onChanged: (value) => notifier.stravaClientIdChanged(value),
                    ),
                    TextFormField(
                      controller: _stravaClientSecretController,
                      decoration: const InputDecoration(labelText: "Client Secret"),
                      obscureText: true,
                      onChanged: (value) => notifier.stravaClientSecretChanged(value),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Enregistrer les identifiants Strava"),
                      onPressed: () async {
                        final success = await notifier.saveStravaCredentials();
                        if (mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✅ Identifiants Strava enregistrés"), backgroundColor: Colors.green),
                          );
                        }
                      },
                    ),
                    _StravaConnectSection(),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // Logique pour naviguer vers la page des mentions légales
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LegalNoticePage()),
                          );
                        },
                        child: const Text(
                          'Consulter les mentions légales',
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
}
// À la fin de votre fichier profile_form_page.dart

// Provider pour vérifier l'état de la connexion (très performant)
final isStravaConnectedProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(stravaServiceProvider).isConnected();
});

// dans lib/pages/profile_form_page.dart

class _StravaConnectSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnectedAsync = ref.watch(isStravaConnectedProvider);
    final stravaService = ref.read(stravaServiceProvider);
    
    // On récupère le notifier du formulaire pour appeler la déconnexion
    final notifier = ref.read(profileFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("🔗 Connexion Strava", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        
        isConnectedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text("Erreur: $err"),
          data: (isConnected) {
            if (isConnected) {
              // ✅ Si l'utilisateur est connecté, on affiche le statut ET le bouton de déconnexion
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
                    onPressed: () {
                      // On appelle la nouvelle méthode du notifier
                      notifier.disconnectStrava();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("Se déconnecter de Strava"),
                  ),
                ],
              );
            } else {
              // Si l'utilisateur n'est pas connecté
              return ElevatedButton.icon(
                onPressed: () async {
                  await stravaService.launchAuthUrl();
                },
                icon: const Icon(Icons.link),
                label: const Text("Connecter mon compte Strava"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC4C02), // Couleur Strava
                  foregroundColor: Colors.white,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}