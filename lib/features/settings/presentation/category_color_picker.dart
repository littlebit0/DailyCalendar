import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';

const categoryColorPresets = [
  0xff2563eb,
  0xff10b981,
  0xfff59e0b,
  0xffec4899,
  0xff8b5cf6,
  0xff14b8a6,
  0xff64748b,
  0xffef4444,
];

Future<int?> showCategoryColorPicker(BuildContext context, int initialColor) {
  var selected = initialColor;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: DailyUi.pageBackground(context),
        surfaceTintColor: Colors.transparent,
        title: _colorDialogTitle(context.tr('색상'), Icons.palette_outlined),
        content: SingleChildScrollView(
          child: CategoryColorPalette(
            colorValue: selected,
            onChanged: (color) => setState(() => selected = color),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: Text(context.tr('적용')),
          ),
        ],
      ),
    ),
  );
}

class CategoryColorPalette extends StatefulWidget {
  const CategoryColorPalette({
    super.key,
    required this.colorValue,
    required this.onChanged,
  });
  final int colorValue;
  final ValueChanged<int> onChanged;

  @override
  State<CategoryColorPalette> createState() => _CategoryColorPaletteState();
}

class _CategoryColorPaletteState extends State<CategoryColorPalette> {
  late final Set<int> _colors = {widget.colorValue, ...categoryColorPresets};
  bool _picking = false;

  @override
  void didUpdateWidget(CategoryColorPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    _colors.add(widget.colorValue);
  }

  Future<void> _customColor() async {
    if (_picking) return;
    _picking = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final color = await showDialog<int>(
        context: context,
        builder: (_) => _RgbColorDialog(initialColor: widget.colorValue),
      );
      if (color == null || !mounted) return;
      setState(() => _colors.add(color));
      widget.onChanged(color);
    } finally {
      _picking = false;
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final color in _colors)
        Semantics(
          label:
              '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}',
          selected: widget.colorValue == color,
          child: SizedBox.square(
            dimension: 40,
            child: ChoiceChip(
              key: ValueKey('category-color-$color'),
              selected: widget.colorValue == color,
              label: const SizedBox.shrink(),
              labelPadding: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              showCheckmark: false,
              clipBehavior: Clip.antiAlias,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: CircleAvatar(radius: 8, backgroundColor: Color(color)),
              onSelected: (_) => widget.onChanged(color),
            ),
          ),
        ),
      Tooltip(
        message: context.tr('사용자 지정 색상'),
        child: SizedBox.square(
          dimension: 40,
          child: ChoiceChip(
            selected: false,
            label: const SizedBox.shrink(),
            labelPadding: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            showCheckmark: false,
            clipBehavior: Clip.antiAlias,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
              ),
            ),
            onSelected: (_) => _customColor(),
          ),
        ),
      ),
    ],
  );
}

Widget _colorDialogTitle(
  String title,
  IconData icon, {
  Color color = DailyUi.purple,
}) => Row(
  children: [
    DailySettingsIcon(icon: icon, color: color),
    const SizedBox(width: 10),
    Expanded(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    ),
  ],
);

class _RgbColorDialog extends StatefulWidget {
  const _RgbColorDialog({required this.initialColor});

  final int initialColor;

  @override
  State<_RgbColorDialog> createState() => _RgbColorDialogState();
}

class _RgbColorDialogState extends State<_RgbColorDialog> {
  late final List<int> _channels;
  late final List<TextEditingController> _controllers;
  late HSVColor _hsv;

  int get _colorValue =>
      0xff000000 | (_channels[0] << 16) | (_channels[1] << 8) | _channels[2];

  @override
  void initState() {
    super.initState();
    _channels = [
      (widget.initialColor >> 16) & 0xff,
      (widget.initialColor >> 8) & 0xff,
      widget.initialColor & 0xff,
    ];
    _controllers = [
      for (final value in _channels) TextEditingController(text: '$value'),
    ];
    _hsv = HSVColor.fromColor(Color(_colorValue));
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final pickerWidth = (screenSize.width - 128).clamp(200.0, 360.0);
    final maxContentHeight = screenSize.height * 0.62;
    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _colorDialogTitle(
        context.tr('사용자 지정 색상'),
        Icons.palette_outlined,
        color: DailyUi.purple,
      ),
      content: SizedBox(
        width: pickerWidth,
        height: maxContentHeight,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _colorPalette(pickerWidth),
              const SizedBox(height: 14),
              for (var index = 0; index < 3; index++)
                _channelRow(index, const ['R', 'G', 'B'][index]),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('취소')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_colorValue),
          style: FilledButton.styleFrom(
            backgroundColor: DailyUi.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(context.tr('적용')),
        ),
      ],
    );
  }

  Widget _colorPalette(double width) {
    final size = Size(width, 180);
    return GestureDetector(
      key: const Key('category-color-palette'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _setPaletteColor(details.localPosition, size),
      onPanStart: (details) => _setPaletteColor(details.localPosition, size),
      onPanUpdate: (details) => _setPaletteColor(details.localPosition, size),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Colors.purple,
                        Colors.red,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.transparent, Colors.black],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (_hsv.hue / 360 * size.width - 8).clamp(
                  0,
                  size.width - 16,
                ),
                top: (_paletteVerticalPosition * size.height - 8).clamp(
                  0,
                  size.height - 16,
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(_colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _paletteVerticalPosition {
    if (_hsv.value >= 0.999 && _hsv.saturation < 0.999) {
      return _hsv.saturation / 2;
    }
    return 0.5 + (1 - _hsv.value) / 2;
  }

  void _setPaletteColor(Offset position, Size size) {
    final hue = (position.dx / size.width).clamp(0.0, 1.0) * 360;
    final vertical = (position.dy / size.height).clamp(0.0, 1.0);
    final saturation = vertical <= 0.5 ? vertical * 2 : 1.0;
    final value = vertical <= 0.5 ? 1.0 : (1 - vertical) * 2;
    _applyHsv(HSVColor.fromAHSV(1, hue, saturation, value));
  }

  void _applyHsv(HSVColor value) {
    final color = value.toColor();
    setState(() {
      _hsv = value;
      _channels[0] = (color.r * 255).round();
      _channels[1] = (color.g * 255).round();
      _channels[2] = (color.b * 255).round();
      for (var index = 0; index < 3; index++) {
        _controllers[index].text = '${_channels[index]}';
      }
    });
  }

  void _syncHsvFromChannels() {
    _hsv = HSVColor.fromColor(Color(_colorValue));
  }

  Widget _channelRow(int index, String label) {
    return Row(
      children: [
        SizedBox(width: 22, child: Text(label)),
        Expanded(
          child: Slider(
            value: _channels[index].toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: '${_channels[index]}',
            onChanged: (value) {
              final channel = value.round();
              setState(() {
                _channels[index] = channel;
                _controllers[index].text = '$channel';
                _syncHsvFromChannels();
              });
            },
          ),
        ),
        SizedBox(
          width: 58,
          child: TextField(
            controller: _controllers[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: '', isDense: true),
            onChanged: (value) {
              final channel = int.tryParse(value);
              if (channel == null) {
                return;
              }
              setState(() {
                _channels[index] = channel.clamp(0, 255).toInt();
                _syncHsvFromChannels();
              });
            },
            onSubmitted: (_) {
              _controllers[index].text = '${_channels[index]}';
            },
          ),
        ),
      ],
    );
  }
}
