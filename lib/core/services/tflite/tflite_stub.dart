class Tensor {
  final List<int> shape = [];
}

class Interpreter {
  static Future<Interpreter> fromFile(dynamic file) async => Interpreter();
  static Future<Interpreter> fromAsset(String assetName) async => Interpreter();
  void allocateTensors() {}
  List<Tensor> getOutputTensors() => [];
  Tensor getOutputTensor(int index) => Tensor();
  void run(dynamic input, dynamic output) {}
  void runForMultipleInputs(List<Object> inputs, Map<int, Object> outputs) {}
  void close() {}
}
