import 'package:abqari_cloud/abqari_cloud.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/edu_strings.dart';
import 'account_controller.dart';
import 'class_page.dart';

class AccountKeys {
  static const signInTab = ValueKey('account-sign-in-tab');
  static const signUpTab = ValueKey('account-sign-up-tab');
  static const email = ValueKey('account-email');
  static const password = ValueKey('account-password');
  static const displayName = ValueKey('account-name');
  static const submit = ValueKey('account-submit');
  static const error = ValueKey('account-error');
  static const notice = ValueKey('account-notice');
  static const signOut = ValueKey('account-sign-out');
  static const retry = ValueKey('account-retry');
  static const sync = ValueKey('account-sync');
  static const joinCode = ValueKey('account-join-code');
  static const join = ValueKey('account-join');
  static const className = ValueKey('account-class-name');
  static const createClass = ValueKey('account-create-class');

  static ValueKey<String> classTile(String id) => ValueKey('account-class-$id');
  static ValueKey<String> leave(String id) => ValueKey('account-leave-$id');
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.controller});

  final AccountController controller;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _joinCode = TextEditingController();
  final _className = TextEditingController();
  bool _signUp = false;
  String? _notice;

  AccountController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.clearError();
    if (_c.status == AccountStatus.signedIn) _c.refreshClasses();
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _joinCode, _className]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.accountTitle)),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_c.busy) const LinearProgressIndicator(),
            if (_c.error case final kind?)
              _Banner(
                key: AccountKeys.error,
                text: strings.cloudError(kind),
                isError: true,
              ),
            if (_notice case final text?)
              _Banner(key: AccountKeys.notice, text: text, isError: false),
            ...switch (_c.status) {
              AccountStatus.starting => [
                  const Center(child: CircularProgressIndicator())
                ],
              AccountStatus.signedOut => _signedOut(context, strings),
              AccountStatus.signedIn => _c.account == null
                  ? [
                      FilledButton(
                        key: AccountKeys.retry,
                        onPressed: _c.busy ? null : _c.start,
                        child: Text(strings.retryButton),
                      ),
                    ]
                  : _signedIn(context, strings, _c.account!),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _signedOut(BuildContext context, EduStrings strings) {
    final language = Localizations.localeOf(context).languageCode;
    return [
      Text(strings.accountIntro),
      const SizedBox(height: 16),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(
            value: false,
            label: Text(strings.signInTab, key: AccountKeys.signInTab),
          ),
          ButtonSegment(
            value: true,
            label: Text(strings.signUpTab, key: AccountKeys.signUpTab),
          ),
        ],
        selected: {_signUp},
        onSelectionChanged: (s) => setState(() {
          _signUp = s.first;
          _notice = null;
          _c.clearError();
        }),
      ),
      const SizedBox(height: 16),
      Form(
        key: _formKey,
        child: Column(
          children: [
            if (_signUp) ...[
              TextFormField(
                key: AccountKeys.displayName,
                controller: _name,
                maxLength: 60,
                decoration: InputDecoration(labelText: strings.displayNameLabel),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? strings.fieldRequired : null,
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              key: AccountKeys.email,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: strings.emailLabel),
              validator: (v) =>
                  (v ?? '').trim().contains('@') ? null : strings.fieldRequired,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: AccountKeys.password,
              controller: _password,
              obscureText: true,
              autofillHints: [
                _signUp ? AutofillHints.newPassword : AutofillHints.password
              ],
              decoration: InputDecoration(labelText: strings.passwordLabel),
              validator: (v) {
                if ((v ?? '').isEmpty) return strings.fieldRequired;
                if (_signUp && v!.length < 8) return strings.passwordTooShort;
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: AccountKeys.submit,
                onPressed: _c.busy ? null : () => _submit(strings, language),
                child: Text(_signUp ? strings.signUpButton : strings.signInButton),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _submit(EduStrings strings, String language) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _notice = null);
    if (_signUp) {
      final result = await _c.signUp(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        locale: language,
      );
      if (result is ConfirmationSent && mounted) {
        setState(() {
          _notice = strings.confirmationSent(result.email);
          _signUp = false;
          _password.clear();
        });
      }
    } else {
      await _c.signIn(_email.text, _password.text);
    }
    if (_c.status == AccountStatus.signedIn) _password.clear();
  }

  List<Widget> _signedIn(
      BuildContext context, EduStrings strings, Account account) {
    final textTheme = Theme.of(context).textTheme;
    final mine = _c.classes.where((c) => c.isMine).toList();
    final joined = _c.classes.where((c) => !c.isMine).toList();
    final canTeach = account.role == AccountRole.teacher;
    return [
      Card(
        child: ListTile(
          leading: const Icon(Icons.account_circle_outlined, size: 40),
          title: Text(account.displayName, style: textTheme.titleMedium),
          subtitle: Text([
            strings.roleName(account.role),
            if (account.email.isNotEmpty) account.email,
          ].join('\n')),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: AccountKeys.sync,
        onPressed: _c.busy ? null : _c.syncNow,
        icon: const Icon(Icons.cloud_upload_outlined),
        label: Text(strings.syncButton),
      ),
      if (_c.lastSync case final at?)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(strings.synced(at), style: textTheme.bodySmall),
        ),
      const SizedBox(height: 24),
      Text(strings.myClassesTitle, style: textTheme.titleMedium),
      const SizedBox(height: 8),
      if (_c.classes.isEmpty) Text(strings.noClasses),
      for (final c in mine)
        Card(
          child: ListTile(
            key: AccountKeys.classTile(c.id),
            leading: const Icon(Icons.groups_outlined),
            title: Text(c.name),
            subtitle: Text(strings.joinCodeIs(c.joinCode)),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ClassPage(controller: _c, schoolClass: c),
            )),
          ),
        ),
      for (final c in joined)
        Card(
          child: ListTile(
            key: AccountKeys.classTile(c.id),
            leading: const Icon(Icons.school_outlined),
            title: Text(c.name),
            trailing: TextButton(
              key: AccountKeys.leave(c.id),
              onPressed: _c.busy ? null : () => _c.leaveClass(c.id),
              child: Text(strings.leaveClassButton),
            ),
          ),
        ),
      const SizedBox(height: 16),
      if (canTeach)
        _InlineAction(
          fieldKey: AccountKeys.className,
          buttonKey: AccountKeys.createClass,
          controller: _className,
          label: strings.classNameLabel,
          button: strings.createClassButton,
          busy: _c.busy,
          onSubmit: (text) async {
            if (await _c.createClass(text) != null) _className.clear();
          },
        )
      else ...[
        Text(strings.joinClassTitle, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        _InlineAction(
          fieldKey: AccountKeys.joinCode,
          buttonKey: AccountKeys.join,
          controller: _joinCode,
          label: strings.joinCodeLabel,
          button: strings.joinButton,
          busy: _c.busy,
          capitalize: true,
          onSubmit: (text) async {
            final joinedClass = await _c.joinClass(text);
            if (joinedClass != null && mounted) {
              _joinCode.clear();
              setState(() => _notice = strings.joined(joinedClass.name));
            }
          },
        ),
      ],
      const SizedBox(height: 32),
      TextButton.icon(
        key: AccountKeys.signOut,
        onPressed: _c.busy
            ? null
            : () async {
                setState(() => _notice = null);
                await _c.signOut();
              },
        icon: const Icon(Icons.logout),
        label: Text(strings.signOutButton),
      ),
    ];
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.fieldKey,
    required this.buttonKey,
    required this.controller,
    required this.label,
    required this.button,
    required this.busy,
    required this.onSubmit,
    this.capitalize = false,
  });

  final Key fieldKey;
  final Key buttonKey;
  final TextEditingController controller;
  final String label;
  final String button;
  final bool busy;
  final bool capitalize;
  final Future<void> Function(String text) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            textCapitalization: capitalize
                ? TextCapitalization.characters
                : TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          key: buttonKey,
          onPressed: busy
              ? null
              : () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) onSubmit(text);
                },
          child: Text(button),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isError ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    color: isError
                        ? scheme.onErrorContainer
                        : scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
