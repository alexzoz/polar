void main() {
  try {
    print(DateTime.parse("2011-12-03T10:15:30+01:00"));
  } catch (e) {
    print("Error: $e");
  }
}
