import 'package:flutter/material.dart';

class CustomPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const CustomPasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<CustomPasswordField> createState() => _CustomPasswordFieldState();
}

class _CustomPasswordFieldState extends State<CustomPasswordField> {
  bool _isObscure = true;
  bool _showIcon = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputChange);
    _showIcon = widget.controller.text.isNotEmpty;
  }

  void _handleInputChange() {
    final bool hasText = widget.controller.text.isNotEmpty;
    if (hasText != _showIcon) {
      setState(() {
        _showIcon = hasText;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleInputChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _isObscure,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: _showIcon
            ? Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
    );
  }
}
