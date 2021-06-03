extension DoubleExtension on double {
  double truncateDecimal(int x) {
    String str = this.toString();
    return double.tryParse(str.split('.')[0] +
        '.' +
        (str.split('.')[1] + '0' * x).substring(0, x));
  }
}
