import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// 2-column micro-pill grid showing password strength requirements.
/// Used by [ChangePasswordScreen] and [SignUpScreen].
class PasswordRequirementsWidget extends StatelessWidget {
  const PasswordRequirementsWidget({
    super.key,
    required this.password,
  });

  final String password;

  bool get _hasMinLength => password.length >= 8;
  bool get _hasUppercase => password.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => password.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => password.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]'));

  @override
  Widget build(BuildContext context) {
    final requirements = <({String label, bool met})>[
      (label: '8+ characters', met: _hasMinLength),
      (label: 'Capital letter', met: _hasUppercase),
      (label: 'Lowercase letter', met: _hasLowercase),
      (label: 'Number', met: _hasDigit),
      (label: 'Special character', met: _hasSpecial),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: requirements.map((r) => _RequirementPill(r: r)).toList(),
      ),
    );
  }
}

class _RequirementPill extends StatelessWidget {
  const _RequirementPill({required this.r});

  final ({String label, bool met}) r;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(r.met),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: r.met
              ? AppTheme.botanicalPrimary.withOpacity(0.10)
              : Colors.grey.withOpacity(0.10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              r.met ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 13,
              color: r.met ? AppTheme.botanicalPrimary : AppTheme.textTertiary,
            ),
            const SizedBox(width: 5),
            Text(
              r.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: r.met ? FontWeight.w600 : FontWeight.w400,
                color: r.met ? AppTheme.botanicalPrimary : AppTheme.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
