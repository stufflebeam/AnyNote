import 'dart:math';
import 'dart:ui';

import 'package:anynote/GlobalConfig.dart';
import 'package:anynote/MainController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

extension ColorExtension on int? {
  // 扩展方法，自动添加透明通道
  Color toFullARGB() {
    if (this == null) return Color(0xFFFFFFFF);
    return Color(this! | 0xFF000000);
  }
}

class IDGenerator {
  static const int _offlineIdMin = 1000000000; // 1 billion
  static const int _offlineIdMax = 2147483647; // Max value for int

  static final Random _random = Random();

  // Generate a random offline ID
  static int generateOfflineId() {
    return _offlineIdMin + _random.nextInt(_offlineIdMax - _offlineIdMin);
  }

  // Check if an ID is an offline ID
  static bool isOfflineId(int id) {
    return id >= _offlineIdMin;
  }
}

class MarkdownEditingController extends TextEditingController {
  final String zeroWidthChar =
      '\u200B'; // Unicode character for zero-width space

  String replacePatternWithZeroWidth(String input, String pattern) {
    RegExp regex = RegExp(pattern);
    int totalReplacements = 0;

    // 使用正则表达式的 `allMatches` 方法来找到所有匹配
    Iterable<RegExpMatch> matches = regex.allMatches(input);

    String result = input;
    // 计算总替换长度
    for (RegExpMatch match in matches) {
      totalReplacements += match.group(0)!.length;
    }

    // 替换匹配的字符串为空白字符
    result = result.replaceAllMapped(regex, (match) {
      return List.filled(match.group(0)!.length, '').join();
    });

    // 在行尾添加零宽字符
    if (totalReplacements > 0) {
      result += List.filled(totalReplacements, zeroWidthChar).join();
    }

    return result;
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final List<TextSpan> children = [];
    final String text = this.text;

    int startLine = 0;
    int endLine = 0;
    int currentLineIndex = 1;

    if (selection.isValid) {
      startLine = text.substring(0, selection.start).split('\n').length;
      endLine = text.substring(0, selection.end).split('\n').length;
    }

    final List<String> lines = text.split('\n');
    final RegExp exp = RegExp(
        r'(^ *-(?! \[))|(^ *- \[x\])|(^ *- \[ \])|(\*\*\*.+?\*\*\*)|(\*\*.+?\*\*)|(\*.+?\*)|(~~.+?~~)|(`.+?`)|(https?:\/\/[^\s]+)|(!\[.*?\]\(.*?\))|(#[a-zA-Z\u4e00-\u9fa5]+)');
    int lastMatchEnd;

    for (String line in lines) {
      bool showLine =
          currentLineIndex <= endLine && currentLineIndex >= startLine;

      if (RegExp("^#+ ").hasMatch(line)) {
        int level = 0;
        for (int i = 0; i < line.length; i++) {
          if (line[i] == '#') {
            level++;
          } else {
            break;
          }
        }

        Color color;
        switch (level) {
          case 1:
            color = Colors.red;
            break;
          case 2:
            color = Colors.orange;
            break;
          case 3:
            color = Colors.blue;
            break;
          case 4:
            color = Colors.blueAccent;
            break;
          default:
            color = Colors.black;
        }

        if (!showLine) {
          line = replacePatternWithZeroWidth(line, "^#* ");
        }

        children.add(TextSpan(
            text: "$line\n",
            style: TextStyle(
                fontSize: GlobalConfig.fontSize.toDouble(),
                fontWeight: FontWeight.bold,
                color: color)));

        currentLineIndex++;
        continue;
      }

      // if (RegExp(r'!\[.*?\]\(.*?\)').hasMatch(line)) {
      //   final matches = RegExp(r'!\[(.*?)\]\((.*?)\)').allMatches(line);
      //   lastMatchEnd = 0;

      //   for (final match in matches) {
      //     if (match.start > lastMatchEnd) {
      //       children
      //           .add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
      //     }

      //     final altText = match.group(1) ?? '';
      //     final imageUrl = match.group(2) ?? '';

      //     if (showLine) {
      //       children.add(TextSpan(text: line));
      //     } else {
      //       children.add(
      //         TextSpan(children: [
      //           WidgetSpan(
      //             child: Padding(
      //               padding: const EdgeInsets.all(10.0),
      //               child: Image.network(
      //                 imageUrl,
      //                 fit: BoxFit.cover,
      //                 errorBuilder: (context, error, stackTrace) {
      //                   return Icon(
      //                     Icons.image_not_supported_outlined,
      //                     color: Colors.grey[500],
      //                   );
      //                 },
      //               ),
      //             ),
      //           ),
      //         ]),
      //       );
      //     }
      //     lastMatchEnd = match.end;
      //   }

      //   if (lastMatchEnd < line.length) {
      //     children.add(TextSpan(text: line.substring(lastMatchEnd)));
      //   }

      //   children.add(const TextSpan(text: '\n'));
      //   continue;
      // }

      if (line == ('---')) {
        if (showLine) {
          children.add(TextSpan(
            text: '---\n',
            style: style?.copyWith(
                color: Colors.black, fontWeight: FontWeight.bold),
          ));
        } else {
          children.add(TextSpan(children: [
            WidgetSpan(
                child: Divider(
              height: 20,
              color: Colors.grey[500],
            )),
            const WidgetSpan(child: SizedBox.shrink()),
            const WidgetSpan(child: SizedBox.shrink()),
            const WidgetSpan(child: SizedBox.shrink())
          ]));
        }

        currentLineIndex++;
        continue;
      }

      if (RegExp(r'^\s*```[0-9a-zA-Z]*$').hasMatch(line)) {
        if (showLine) {
          children.add(TextSpan(
            text: line == "```\n" ? "```" : "$line\n",
            style: style?.copyWith(
                color: Colors.black, fontWeight: FontWeight.bold),
          ));
        } else {
          var restext =
              line.replaceFirst('```', '').replaceAll(" ", zeroWidthChar);

          var blankcount = (restext.length + 3);

          var blank = List.filled(
            blankcount,
            const WidgetSpan(child: SizedBox.shrink()),
          );

          children.add(TextSpan(children: [
            WidgetSpan(
                child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                ),
                Text(
                  restext,
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                ),
              ],
            )),
            ...blank,
          ]));
        }

        currentLineIndex++;
        continue;
      }

      while (line.startsWith("  ")) {
        line = line.substring(2, line.length);
        children.add(const TextSpan(children: [
          WidgetSpan(
              child: SizedBox(
            width: 10,
          )),
          WidgetSpan(
              child: SizedBox(
            width: 10,
          ))
        ]));
      }

      lastMatchEnd = 0;
      final Iterable<RegExpMatch> matches = exp.allMatches(line);

      for (final RegExpMatch match in matches) {
        if (match.start > lastMatchEnd) {
          children.add(TextSpan(
              text: line.substring(lastMatchEnd, match.start), style: style));
        }

        String matchText = match.group(0)!;
        TextStyle matchStyle = style!;

        if (matchText.trimLeft().startsWith("-") &&
            !(matchText.trimLeft().startsWith("- [")) &&
            !(matchText.trimLeft().startsWith("--"))) {
          if (!showLine) {
            matchText = matchText.replaceFirst('-', '•');
          }

          matchStyle = matchStyle.copyWith(
              color: Colors.black, fontWeight: FontWeight.bold);
        }

        if (matchText.trimLeft().startsWith('- [ ]')) {
          if (!showLine) {
            matchText =
                matchText.replaceFirst('- [ ]', "${zeroWidthChar * 4}▢");
          }
          matchStyle = matchStyle.copyWith(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          );
        }

        if (matchText.trimLeft().startsWith('- [x]')) {
          if (!showLine) {
            matchText =
                matchText.replaceFirst('- [x]', "${zeroWidthChar * 4}✓");
          }
          matchStyle = matchStyle.copyWith(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          );
        }

        if (matchText.startsWith('***') && matchText.endsWith('***')) {
          matchStyle = matchStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Colors.blueAccent,
                  Colors.yellowAccent,
                  Colors.blueAccent
                ],
                tileMode: TileMode.repeated,
              ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
          );
          if (!showLine) {
            matchText = matchText
                .replaceFirst('***', zeroWidthChar * 3)
                .replaceFirst('***', zeroWidthChar * 3);
          }
        } else if (matchText.startsWith('**') && matchText.endsWith('**')) {
          matchStyle = matchStyle.copyWith(
              fontWeight: FontWeight.bold, color: Colors.black);
          if (!showLine) {
            matchText = matchText
                .replaceFirst('**', zeroWidthChar * 2)
                .replaceFirst('**', zeroWidthChar * 2);
          }
        } else if (matchText.startsWith('*') && matchText.endsWith('*')) {
          matchStyle = matchStyle.copyWith(fontStyle: FontStyle.italic);
          if (!showLine) {
            matchText = matchText
                .replaceFirst('*', zeroWidthChar)
                .replaceFirst('*', zeroWidthChar);
          }
        }

        if (matchText.startsWith('~~') && matchText.endsWith('~~')) {
          matchStyle = matchStyle.copyWith(
              decoration: TextDecoration.lineThrough, color: Colors.black45);
          if (!showLine) {
            matchText = matchText
                .replaceFirst('~~', zeroWidthChar * 2)
                .replaceFirst('~~', zeroWidthChar * 2);
          }
        }

        if (matchText.startsWith('`') && matchText.endsWith('`')) {
          matchStyle = matchStyle.copyWith(
              backgroundColor: Colors.grey.withOpacity(0.2));
          if (!showLine) {
            matchText = matchText
                .replaceFirst('`', zeroWidthChar)
                .replaceFirst('`', zeroWidthChar);
          }
        }

        if (matchText.startsWith('http') || matchText.startsWith('www')) {
          matchStyle = matchStyle.copyWith(
              color: Colors.blue, decoration: TextDecoration.underline);
        }

        if (matchText.startsWith('#')) {
          matchStyle = matchStyle.copyWith(
            color: Colors.deepPurpleAccent,
            fontSize: 14,
          );
          if (!showLine) {
            matchText = matchText.replaceFirst('#', zeroWidthChar);
          }
        }

        children.add(TextSpan(text: matchText, style: matchStyle));
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        children
            .add(TextSpan(text: line.substring(lastMatchEnd), style: style));
      }

      children.add(TextSpan(text: '\n', style: style));
      currentLineIndex++;
    }

    if (children.isNotEmpty && children.last.text == '\n') {
      children.removeLast();
    }

    return TextSpan(style: style, children: children);
  }
}

class CustomMarkdownDisplay extends StatelessWidget {
  final String text;
  final double lineheight;
  CustomMarkdownDisplay({required this.text, this.lineheight = 1.5});

  final String zeroWidthChar = '';

  String replacePatternWithZeroWidth(String input, String pattern) {
    RegExp regex = RegExp(pattern);
    return input.replaceAllMapped(regex, (match) {
      return List.filled(match.group(0)!.length, zeroWidthChar).join();
    });
  }

  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> children = [];
    final List<String> lines = text.split('\n');

    final RegExp exp = RegExp(
        r'(^ *-(?! \[))|(^ *- \[x\])|(^ *- \[ \])|(\*\*\*.+?\*\*\*)|(\*\*.+?\*\*)|(\*.+?\*)|(~~.+?~~)|(`.+?`)|(https?:\/\/[^\s]+)|(!\[.*?\]\(.*?\))|(#[a-zA-Z\u4e00-\u9fa5]+)');
    int lastMatchEnd;

    for (String line in lines) {
      if (RegExp("^#+ ").hasMatch(line)) {
        int level = 0;
        for (int i = 0; i < line.length; i++) {
          if (line[i] == '#') {
            level++;
          } else {
            break;
          }
        }

        Color color;
        switch (level) {
          case 1:
            color = Colors.red;
            break;
          case 2:
            color = Colors.orange;
            break;
          case 3:
            color = Colors.blue;
            break;
          case 4:
            color = Colors.blueAccent;
            break;
          default:
            color = Colors.black;
        }

        line = replacePatternWithZeroWidth(line, "^#+ ");
        children.add(TextSpan(
            text: "$line\n",
            style: TextStyle(
                fontSize: 8 * (2 - 0.1 * level),
                fontWeight: FontWeight.bold,
                color: color)));
        continue;
      }

      if (RegExp(r'!\[.*?\]\(.*?\)').hasMatch(line)) {
        final matches = RegExp(r'!\[(.*?)\]\((.*?)\)').allMatches(line);
        lastMatchEnd = 0;

        for (final match in matches) {
          if (match.start > lastMatchEnd) {
            children
                .add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
          }

          final altText = match.group(1) ?? '';
          final imageUrl = match.group(2) ?? '';

          children.add(
            TextSpan(children: [
              WidgetSpan(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey[500],
                    );
                  },
                ),
              ),
            ]),
          );

          lastMatchEnd = match.end;
        }

        if (lastMatchEnd < line.length) {
          children.add(TextSpan(text: line.substring(lastMatchEnd)));
        }

        children.add(const TextSpan(text: '\n'));
        continue;
      }

      if (line == ('---')) {
        children.add(TextSpan(children: [
          WidgetSpan(
              child: Divider(
            height: 20,
            color: Colors.grey[500],
          )),
        ]));

        continue;
      }

      if (RegExp(r'^\s*```[0-9a-zA-Z]*$').hasMatch(line)) {
        var restext = line.trim().replaceFirst('```', '');

        var blankcount = (restext.length + 3);

        var blank = List.filled(
          blankcount,
          const WidgetSpan(child: SizedBox.shrink()),
        );

        children.add(TextSpan(children: [
          WidgetSpan(
              child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
              ),
              Text(
                restext,
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
              ),
            ],
          )),
          ...blank,
        ]));
        continue;
      }

      while (line.startsWith("  ")) {
        line = line.substring(2, line.length);
        children.add(const TextSpan(children: [
          WidgetSpan(
              child: SizedBox(
            width: 10,
          )),
          WidgetSpan(
              child: SizedBox(
            width: 10,
          ))
        ]));
      }

      lastMatchEnd = 0;
      final Iterable<RegExpMatch> matches = exp.allMatches(line);

      for (final RegExpMatch match in matches) {
        if (match.start > lastMatchEnd) {
          children.add(TextSpan(
              text: line.substring(lastMatchEnd, match.start),
              style: TextStyle()));
        }

        String matchText = match.group(0)!;
        TextStyle matchStyle = TextStyle();

        if (matchText.trimLeft().startsWith("-") &&
            !(matchText.trimLeft().startsWith("- [")) &&
            !(matchText.trimLeft().startsWith("--"))) {
          matchText = matchText.replaceFirst('-', '•');
          matchStyle = matchStyle.copyWith(
              color: Colors.black, fontWeight: FontWeight.bold);
        }

        if (matchText.trimLeft().startsWith('- [ ]')) {
          matchText = matchText.replaceFirst('- [ ]', "${zeroWidthChar * 4}▢");
          matchStyle = matchStyle.copyWith(
              color: Colors.red, fontWeight: FontWeight.bold);
        }

        if (matchText.trimLeft().startsWith('- [x]')) {
          matchText = matchText.replaceFirst('- [x]', "${zeroWidthChar * 4}✓");
          matchStyle = matchStyle.copyWith(
              color: Colors.green, fontWeight: FontWeight.bold);
        }

        if (matchText.startsWith('***') && matchText.endsWith('***')) {
          matchStyle = matchStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Colors.blueAccent,
                  Colors.yellowAccent,
                  Colors.blueAccent
                ],
                tileMode: TileMode.repeated,
              ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
          );
          matchText = matchText
              .replaceFirst('***', zeroWidthChar * 3)
              .replaceFirst('***', zeroWidthChar * 3);
        } else if (matchText.startsWith('**') && matchText.endsWith('**')) {
          matchStyle = matchStyle.copyWith(
              fontWeight: FontWeight.bold, color: Colors.black);
          matchText = matchText
              .replaceFirst('**', zeroWidthChar * 2)
              .replaceFirst('**', zeroWidthChar * 2);
        } else if (matchText.startsWith('*') && matchText.endsWith('*')) {
          matchStyle = matchStyle.copyWith(fontStyle: FontStyle.italic);
          matchText = matchText
              .replaceFirst('*', zeroWidthChar)
              .replaceFirst('*', zeroWidthChar);
        }

        if (matchText.startsWith('~~') && matchText.endsWith('~~')) {
          matchStyle = matchStyle.copyWith(
              decoration: TextDecoration.lineThrough, color: Colors.black45);
          matchText = matchText
              .replaceFirst('~~', zeroWidthChar * 2)
              .replaceFirst('~~', zeroWidthChar * 2);
        }

        if (matchText.startsWith('`') && matchText.endsWith('`')) {
          matchStyle = matchStyle.copyWith(
              backgroundColor: Colors.grey.withOpacity(0.2));
          matchText = matchText
              .replaceFirst('`', zeroWidthChar)
              .replaceFirst('`', zeroWidthChar);
        }

        if (matchText.startsWith('http') || matchText.startsWith('www')) {
          matchStyle = matchStyle.copyWith(
              color: Colors.blue, decoration: TextDecoration.underline);
        }

        if (matchText.startsWith('#')) {
          matchStyle = matchStyle.copyWith(
            color: Colors.deepPurpleAccent,
            fontSize: 14,
          );
          matchText = matchText.replaceFirst('#', zeroWidthChar);
        }

        children.add(TextSpan(text: matchText, style: matchStyle));
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        children.add(
            TextSpan(text: line.substring(lastMatchEnd), style: TextStyle()));
      }

      children.add(const TextSpan(text: '\n', style: TextStyle()));
    }

    if (children.isNotEmpty && children.last.text == '\n') {
      children.removeLast();
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    final mainController = Get.find<MainController>();
    return Obx(
      () => RichText(
        overflow: TextOverflow.clip,
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(
                color: Colors.grey[700],
                fontSize: mainController.fontSize.toDouble(),
                //letterSpacing: 1.2,
                //height: 1.8
              ),
          children: _buildTextSpans(text),
        ),
      ),
    );
  }
}

void IndentText(TextEditingController controller, FocusNode controllerfn) {
  final text = controller.text;
  final selection = controller.selection;
  final lines = text.split('\n');

  final startLine = selection.start == -1
      ? 0
      : text.substring(0, selection.start).split('\n').length - 1;
  final endLine = selection.end == -1
      ? startLine
      : text.substring(0, selection.end).split('\n').length - 1;

  for (int i = startLine; i <= endLine; i++) {
    if (i >= 0 && i < lines.length) {
      final line = lines[i];
      final newLine = '  ' + line;
      lines[i] = newLine;
    }
  }

  final newText = lines.join('\n');
  controller.text = newText;
  controller.selection = TextSelection(
    baseOffset: selection.start + 2 * (startLine == endLine ? 1 : 0),
    extentOffset: selection.end + 2 * (endLine - startLine + 1),
  );

  Future.delayed(const Duration(milliseconds: 1), () {
    controllerfn.requestFocus();
  });
}

void UnindentText(TextEditingController controller, FocusNode controllerfn) {
  final text = controller.text;
  final selection = controller.selection;
  final lines = text.split('\n');

  final startLine = selection.start == -1
      ? 0
      : text.substring(0, selection.start).split('\n').length - 1;
  final endLine = selection.end == -1
      ? startLine
      : text.substring(0, selection.end).split('\n').length - 1;

  for (int i = startLine; i <= endLine; i++) {
    if (i >= 0 && i < lines.length) {
      final line = lines[i];
      if (line.startsWith("  ")) {
        final newLine = line.substring(2);
        lines[i] = newLine;
      }
    }
  }

  final newText = lines.join('\n');
  controller.text = newText;
  controller.selection = TextSelection(
    baseOffset: selection.start - 2 * (startLine == endLine ? 1 : 0),
    extentOffset: selection.end - 2 * (endLine - startLine + 1),
  );

  Future.delayed(const Duration(milliseconds: 1), () {
    controllerfn.requestFocus();
  });
}

void TextChangeEx(TextEditingController _controller, String _lastchange) {
  final text = _controller.text;
  final selection = _controller.selection;
  if (text.length > _lastchange.length &&
      selection.baseOffset > 3 &&
      text.length >= selection.baseOffset) {
    if (text[selection.baseOffset - 1] == '\n' && text.length > 3) {
      int lineStart = text.lastIndexOf('\n', selection.baseOffset - 2);
      lineStart = lineStart == -1 ? 0 : lineStart + 1;

      final currentLine = text.substring(lineStart, selection.baseOffset - 1);

      if (currentLine.trim() == "-") {
        final newText =
            text.replaceRange(lineStart - 1, selection.baseOffset, '\n');
        _controller.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.fromPosition(TextPosition(offset: lineStart)),
        );
        return;
      }

      if (currentLine.trim() == "- [ ]") {
        final newText =
            text.replaceRange(lineStart - 1, selection.baseOffset, '\n');
        _controller.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.fromPosition(TextPosition(offset: lineStart)),
        );
        return;
      }

      final match = RegExp(r'^(\s*)- ').firstMatch(currentLine);

      if (currentLine.trim().startsWith("- [ ] ") ||
          currentLine.trim().startsWith("- [x] ")) {
        var splitstr =
            currentLine.trim().startsWith("- [ ] ") ? "- [ ] " : "- [x] ";
        final indentation = currentLine.split(splitstr)[0];
        final newText = text.replaceRange(
            selection.baseOffset, selection.baseOffset, '$indentation- [ ] ');
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.fromPosition(TextPosition(
              offset: selection.baseOffset + indentation.length + 6)),
        );
      } else if (match != null) {
        final indentation = match.group(1);
        final newText = text.replaceRange(
            selection.baseOffset, selection.baseOffset, '${indentation}- ');
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.fromPosition(TextPosition(
              offset: selection.baseOffset + indentation!.length + 2)),
        );
      }
    }
  }
}

Color darkenColor(Color color, [double amount = 0.1]) {
  assert(amount >= 0 && amount <= 1);
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}
