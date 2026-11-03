from pathlib import Path
p=Path('lib/features/settings/presentation/academic_profile_page.dart');s=p.read_text();start=s.index('                    return Container(',s.index('final hasTimetable'));end=s.index('                      child: ListTile(',start)
s=s[:start]+'''                    return Material(
                      color: chosen ? colors.primaryContainer.withValues(alpha: .35) : colors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: chosen ? colors.primary : DailyUi.separator(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
'''+s[end:]
s=s.replace('child: Row(\n        mainAxisSize: MainAxisSize.min,\n        children: [', 'child: Wrap(\n        spacing: 4,\n        crossAxisAlignment: WrapCrossAlignment.center,\n        children: [',1)
s=s.replace("                              if (choice != null && mounted)\n                                setState(\n                                  () =>\n                                      _region = choice == 'all' ? null : choice,\n                                );", "                              if (choice != null && mounted) {\n                                setState(() => _region = choice == 'all' ? null : choice);\n                              }")
p.write_text(s)
p=Path('lib/core/academic/university_regions.dart');s=p.read_text().replace("import 'dart:ui';\n",'').replace("    if (json['schemaVersion'] != 1)\n      throw const FormatException('Invalid region directory');", "    if (json['schemaVersion'] != 1) {\n      throw const FormatException('Invalid region directory');\n    }");p.write_text(s)
p=Path('lib/features/settings/presentation/university_region_map.dart');s=p.read_text().replace('      if (!result.values.any((other) => other.inflate(3).overlaps(rect)))\n        break;', '      if (!result.values.any((other) => other.inflate(3).overlaps(rect))) {\n        break;\n      }');p.write_text(s)
p=Path('test/features/settings/academic_profile_page_test.dart');s=p.read_text();start=s.index('        final image = await');end=s.index('        await save(tester);',start)
s=s[:start]+'''        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('work/academic-region-ui-20261011/profile-${dark ? 'dark' : 'light'}.png').writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
'''+s[end:];p.write_text(s)
