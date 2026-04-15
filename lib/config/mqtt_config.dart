class MqttConfig {
  MqttConfig._();

  // HiveMQ Cloud
  static const String host = 'flutter-app-1d64c6a1.a01.euc1.aws.hivemq.cloud';
  static const int tlsPort = 8883;

  // Flutter web / Chrome
  static const String wsUrl =
      'flutter-app-1d64c6a1.a01.euc1.aws.hivemq.cloud:8884/mqtt';

  static const String username = 'tanthanh1';
  static const String password = 'Tao040204@';

  // Topic
  static const String fleetStateTopic = 'vehicles/+/state';

  static String commandTopic(String vehicleId) => 'vehicles/$vehicleId/command';
  static String ackTopic(String vehicleId) => 'vehicles/$vehicleId/ack';
}
