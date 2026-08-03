String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a new password';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'\d').hasMatch(value)) {
    return 'Password must include at least one number';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];]').hasMatch(value)) {
    return 'Password must include a special character';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String newPassword) {
  if (value == null || value.isEmpty) {
    return 'Please confirm new password';
  }
  if (value != newPassword) {
    return 'Passwords do not match';
  }
  return null;
}
