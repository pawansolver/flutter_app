String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a new password';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (value.length > 72) {
    return 'Password must be no more than 72 characters';
  }
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Password must include a lowercase letter';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must include an uppercase letter';
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
