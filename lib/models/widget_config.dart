class WidgetConfig {
  const WidgetConfig({
    required this.id,
    this.style = 'number',
    required this.eventIds,
    this.theme = 'blue',
    this.backgroundOpacity = 1,
    this.textTone = 'auto',
    this.photoScale = 1,
    this.photoX = 0,
    this.photoY = 0,
    this.photoDim = 0.6,
  });
  final String id, style, theme, textTone;
  final double backgroundOpacity, photoScale, photoX, photoY, photoDim;
  final List<String> eventIds;
  WidgetConfig copyWith({
    String? style,
    List<String>? eventIds,
    String? theme,
    double? backgroundOpacity,
    String? textTone,
    double? photoScale,
    double? photoX,
    double? photoY,
    double? photoDim,
  }) => WidgetConfig(
    id: id,
    style: style ?? this.style,
    eventIds: eventIds ?? this.eventIds,
    theme: theme ?? this.theme,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    textTone: textTone ?? this.textTone,
    photoScale: photoScale ?? this.photoScale,
    photoX: photoX ?? this.photoX,
    photoY: photoY ?? this.photoY,
    photoDim: photoDim ?? this.photoDim,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'style': style,
    'eventIds': eventIds,
    'theme': theme,
    'backgroundOpacity': backgroundOpacity,
    'textTone': textTone,
    'photoScale': photoScale,
    'photoX': photoX,
    'photoY': photoY,
    'photoDim': photoDim,
  };
  factory WidgetConfig.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final ids = json['eventIds'];
    final tone = json.containsKey('textTone') ? json['textTone'] : 'auto';
    if (id is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id) ||
        ![
          'number',
          'photo',
          'dual',
          'list',
          'ring',
          'calendar',
          'ticket',
          'bloom',
        ].contains(json['style']) ||
        !['blue', 'rose', 'green', 'ink'].contains(json['theme']) ||
        !['auto', 'light', 'dark'].contains(tone) ||
        ids is! List ||
        ids.isEmpty ||
        ids.length > 5 ||
        ids.any((id) => id is! String) ||
        ids.toSet().length != ids.length ||
        (json['style'] != 'list' && ids.length != 1)) {
      throw const FormatException('小组件配置无效');
    }
    return WidgetConfig(
      id: id,
      style: json['style'] as String,
      eventIds: List.unmodifiable(ids.cast<String>()),
      theme: json['theme'] as String,
      backgroundOpacity: _number(json, 'backgroundOpacity', 1, 0, 1),
      textTone: tone as String,
      photoScale: _number(json, 'photoScale', 1, 1, 3),
      photoX: _number(json, 'photoX', 0, -1, 1),
      photoY: _number(json, 'photoY', 0, -1, 1),
      photoDim: _number(json, 'photoDim', 0.6, 0, 0.85),
    );
  }

  static double _number(
    Map<String, dynamic> json,
    String key,
    double fallback,
    double minimum,
    double maximum,
  ) {
    if (!json.containsKey(key)) return fallback;
    final value = json[key];
    if (value is! num ||
        !value.isFinite ||
        value < minimum ||
        value > maximum) {
      throw const FormatException('小组件配置无效');
    }
    return value.toDouble();
  }
}
