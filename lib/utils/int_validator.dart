String? intFormValidator(String? input) {
  if (input == null || input.isEmpty) {
    return null;
  }

  if (int.tryParse(input) == null) {
    return '整数を入力してください';
  }
  return null;
}
