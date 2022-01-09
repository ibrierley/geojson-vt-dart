extension JSList<T> on List<T> {
  //static final _startValues = Expando<double>();
  static final _startValues = Expando<num>();
  static final _sizeValues = Expando<num>();
  static final _endValues = Expando<num>();


  num get start => _startValues[this] ?? 0;
  set start(num x) => _startValues[this] = x;

  num get size => _sizeValues[this] ?? 0;
  set size(num x) => _sizeValues[this] = x;

  num get end => _endValues[this] ?? 0;
  set end(num x) => _endValues[this] = x;

}