import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Translucent dark navy input field with animated focus glow and border highlights.
class AnimatedLoginField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final VoidCallback? onFieldSubmitted;

  const AnimatedLoginField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  State<AnimatedLoginField> createState() => _AnimatedLoginFieldState();
}

class _AnimatedLoginFieldState extends State<AnimatedLoginField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic border color based on focus
    final borderColor = _isFocused
        ? AppColors.primary
        : const Color(0xFF2C3558).withValues(alpha: 0.85);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: const Color(0xFF12162B).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: _isFocused ? 1.6 : 1.2,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: AppColors.gemCyan.withValues(alpha: 0.12),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.isPassword && _obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
        style: const TextStyle(
          color: Color(0xFFF8FAFF),
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
        cursorColor: AppColors.gemCyan,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF7E88A6),
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              widget.prefixIcon,
              size: 20,
              color: _isFocused ? AppColors.gemCyan : const Color(0xFF7E88A6),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: _isFocused
                        ? AppColors.primaryLight
                        : const Color(0xFF7E88A6),
                  ),
                  tooltip: _obscureText ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() => _obscureText = !_obscureText);
                  },
                )
              : null,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: const TextStyle(
            color: AppColors.accentNeon,
            fontSize: 12,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
