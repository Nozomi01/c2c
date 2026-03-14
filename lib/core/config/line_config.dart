/// LINE Login channel ID. Override via --dart-define=LINE_CHANNEL_ID=... if needed.
const String lineChannelId = String.fromEnvironment(
  'LINE_CHANNEL_ID',
  defaultValue: '2009436562',
);
