import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../profile_form/profile_form_state.dart';
import '../../ui/theme/app_theme.dart';
import '../../widget/adaptive_page_body.dart';
import '../../widget/card_shell.dart';

enum ProfileField { firstName, height, weight, garmin }

class ProfileContent extends StatelessWidget {
  final ProfileFormState state;
  final String email;
  final GlobalKey<FormState> formKey;
  final TextEditingController firstName, height, weight, garmin;
  final void Function(ProfileField, String) onTextChanged;
  final ValueChanged<String> onSexChanged, onActivityChanged;
  final VoidCallback onBirthDate, onSave, onOpenGarmin, onLogout, onLegal;
  final Widget strava;
  final bool dirty, saved;
  const ProfileContent(
      {super.key,
      required this.state,
      required this.email,
      required this.formKey,
      required this.firstName,
      required this.height,
      required this.weight,
      required this.garmin,
      required this.onTextChanged,
      required this.onSexChanged,
      required this.onActivityChanged,
      required this.onBirthDate,
      required this.onSave,
      required this.onOpenGarmin,
      required this.onLogout,
      required this.onLegal,
      required this.strava,
      this.dirty = false,
      this.saved = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
        key: formKey,
        child: AdaptivePageBody(maxWidth: 800, children: [
          Text('Mon profil', style: text.headlineLarge),
          const SizedBox(height: 8),
          Text('Des informations à jour pour des besoins adaptés à ton rythme.',
              style: text.bodyLarge),
          const SizedBox(height: 24),
          _Section(
              title: 'Mes informations',
              icon: Icons.person_outline_rounded,
              children: [
                TextFormField(
                    initialValue: email,
                    readOnly: true,
                    decoration: const InputDecoration(
                        labelText: 'Adresse email',
                        helperText: 'Adresse associée au compte',
                        prefixIcon: Icon(Icons.mail_outline_rounded))),
                const SizedBox(height: 16),
                TextFormField(
                    controller: firstName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    onChanged: (v) => onTextChanged(ProfileField.firstName, v),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Champ obligatoire'
                        : null),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                    onPressed: onBirthDate,
                    icon: const Icon(Icons.cake_outlined),
                    label: Text(
                        state.birthDate == null
                            ? 'Choisir ma date de naissance'
                            : 'Naissance : ${DateFormat('dd/MM/yyyy').format(state.birthDate!)}',
                        textAlign: TextAlign.center)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    initialValue: state.sexe,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sexe'),
                    items: const ['Homme', 'Femme']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onSexChanged(v);
                    }),
              ]),
          const SizedBox(height: 20),
          _Section(
              title: 'Mon activité et mes mesures',
              icon: Icons.monitor_heart_outlined,
              children: [
                DropdownButtonFormField<String>(
                    initialValue: state.activite,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Niveau d’activité'),
                    items: const ['Sédentaire', 'Modéré', 'Actif', 'Très actif']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onActivityChanged(v);
                    }),
                const SizedBox(height: 16),
                _MeasureFields(
                    height: height, weight: weight, onChanged: onTextChanged),
              ]),
          const SizedBox(height: 20),
          _Section(
              title: 'Mes connexions',
              icon: Icons.link_rounded,
              children: [
                strava,
                const SizedBox(height: 24),
                TextFormField(
                    controller: garmin,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                        labelText: 'Lien Garmin (optionnel)',
                        hintText: 'https://connect.garmin.com/…'),
                    onChanged: (v) => onTextChanged(ProfileField.garmin, v),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final uri = Uri.tryParse(value);
                      if (uri == null ||
                          !uri.isAbsolute ||
                          !uri.host.contains('garmin.com')) {
                        return 'Lien Garmin invalide';
                      }
                      return null;
                    }),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: onOpenGarmin,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Ouvrir le calendrier Garmin')),
                const SizedBox(height: 8),
                Text(
                    'Copie le lien iCal du calendrier, puis reviens dans l’app.',
                    style: text.bodyMedium),
              ]),
          const SizedBox(height: 20),
          Semantics(
              liveRegion: true,
              child: Text(
                  dirty
                      ? 'Modifications en cours…'
                      : saved
                          ? 'Modifications enregistrées'
                          : 'Les modifications sont enregistrées automatiquement.',
                  style: text.bodyMedium?.copyWith(
                      color: dirty ? AppColors.orange : AppColors.green))),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Enregistrer mon profil')),
          const SizedBox(height: 24),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                TextButton.icon(
                    onPressed: onLogout,
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Se déconnecter')),
                TextButton(
                    onPressed: onLegal, child: const Text('Mentions légales')),
              ]),
        ]));
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section(
      {required this.title, required this.icon, required this.children});
  @override
  Widget build(BuildContext context) => CardShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge))
        ]),
        const SizedBox(height: 20),
        ...children,
      ]));
}

class _MeasureFields extends StatelessWidget {
  final TextEditingController height, weight;
  final void Function(ProfileField, String) onChanged;
  const _MeasureFields(
      {required this.height, required this.weight, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final fields = [
      TextFormField(
          controller: height,
          decoration:
              const InputDecoration(labelText: 'Taille', suffixText: 'cm'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (v) => onChanged(ProfileField.height, v)),
      TextFormField(
          controller: weight,
          decoration:
              const InputDecoration(labelText: 'Poids', suffixText: 'kg'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (v) => onChanged(ProfileField.weight, v)),
    ];
    return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 420
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 16),
                Expanded(child: fields[1])
              ])
            : Column(
                children: [fields[0], const SizedBox(height: 16), fields[1]]));
  }
}
