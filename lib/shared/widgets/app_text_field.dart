import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/app_typography.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool showPasswordToggle;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final Widget? leadingIcon;
  final Widget? trailingAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.hint,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.showPasswordToggle = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.leadingIcon,
    this.trailingAction,
    this.onChanged,
    this.inputFormatters,
    this.autofillHints,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _isObscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final suffixIcon = _suffixIcon(colors);

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _isObscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      textCapitalization: widget.textCapitalization,
      style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.leadingIcon == null
            ? null
            : IconTheme.merge(
                data: IconThemeData(color: colors.textSecondary, size: 20),
                child: widget.leadingIcon!,
              ),
        suffixIcon: suffixIcon,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.ms,
        ),
        constraints: widget.maxLines == 1
            ? const BoxConstraints(minHeight: AppDimensions.inputFieldHeight)
            : null,
        border: OutlineInputBorder(borderRadius: AppDimensions.radiusMd),
      ),
    );
  }

  Widget? _suffixIcon(AppThemeColors colors) {
    if (widget.trailingAction != null) {
      return IconTheme.merge(
        data: IconThemeData(color: colors.textSecondary, size: 20),
        child: widget.trailingAction!,
      );
    }

    if (!widget.obscureText || !widget.showPasswordToggle) return null;

    return IconButton(
      tooltip: _isObscured ? 'Show password' : 'Hide password',
      onPressed: widget.enabled
          ? () {
              setState(() => _isObscured = !_isObscured);
            }
          : null,
      icon: Icon(
        _isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: colors.textSecondary,
      ),
    );
  }
}
