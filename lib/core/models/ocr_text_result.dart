import 'dart:ui';

/// Individual text element inside an OCR line.
class TextElement {
  /// The recognized text string for this word or element.
  final String text;

  /// Detection confidence score (0.0 to 1.0).
  final double confidence;

  /// Bounding box rectangle in image pixel coordinates.
  final Rect? boundingBox;

  /// Recognized language BCP-47 tag (e.g. 'en', 'hi', 'es').
  final String? recognizedLanguage;

  const TextElement({
    required this.text,
    this.confidence = 1.0,
    this.boundingBox,
    this.recognizedLanguage,
  });

  factory TextElement.fromJson(Map<String, dynamic> json) {
    Rect? box;
    if (json['boundingBox'] != null && json['boundingBox'] is Map) {
      final b = json['boundingBox'] as Map<String, dynamic>;
      box = Rect.fromLTWH(
        (b['left'] as num).toDouble(),
        (b['top'] as num).toDouble(),
        (b['width'] as num).toDouble(),
        (b['height'] as num).toDouble(),
      );
    }
    return TextElement(
      text: json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      boundingBox: box,
      recognizedLanguage: json['recognizedLanguage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'confidence': confidence,
        'boundingBox': boundingBox != null
            ? {
                'left': boundingBox!.left,
                'top': boundingBox!.top,
                'width': boundingBox!.width,
                'height': boundingBox!.height,
              }
            : null,
        'recognizedLanguage': recognizedLanguage,
      };

  @override
  String toString() => 'TextElement("$text")';
}

/// Represents a single line of text detected by OCR.
class TextLine {
  /// The raw text string of the line.
  final String text;

  /// List of word elements contained within this line.
  final List<TextElement> elements;

  /// Bounding box rectangle in image pixel coordinates.
  final Rect? boundingBox;

  /// Detection confidence score (0.0 to 1.0).
  final double confidence;

  /// Recognized language BCP-47 tag.
  final String? recognizedLanguage;

  const TextLine({
    required this.text,
    this.elements = const [],
    this.boundingBox,
    this.confidence = 1.0,
    this.recognizedLanguage,
  });

  factory TextLine.fromJson(Map<String, dynamic> json) {
    Rect? box;
    if (json['boundingBox'] != null && json['boundingBox'] is Map) {
      final b = json['boundingBox'] as Map<String, dynamic>;
      box = Rect.fromLTWH(
        (b['left'] as num).toDouble(),
        (b['top'] as num).toDouble(),
        (b['width'] as num).toDouble(),
        (b['height'] as num).toDouble(),
      );
    }
    List<TextElement> elems = [];
    if (json['elements'] != null && json['elements'] is List) {
      elems = (json['elements'] as List)
          .map((e) => TextElement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return TextLine(
      text: json['text'] as String? ?? '',
      elements: elems,
      boundingBox: box,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      recognizedLanguage: json['recognizedLanguage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'elements': elements.map((e) => e.toJson()).toList(),
        'boundingBox': boundingBox != null
            ? {
                'left': boundingBox!.left,
                'top': boundingBox!.top,
                'width': boundingBox!.width,
                'height': boundingBox!.height,
              }
            : null,
        'confidence': confidence,
        'recognizedLanguage': recognizedLanguage,
      };

  @override
  String toString() => 'TextLine("$text", elements: ${elements.length})';
}

/// Represents a distinct paragraph or block of text detected by OCR.
class TextBlock {
  /// The full raw text of the block.
  final String text;

  /// Individual text lines inside this block.
  final List<TextLine> lines;

  /// Bounding box rectangle in image pixel coordinates.
  final Rect? boundingBox;

  /// Detection confidence score (0.0 to 1.0).
  final double confidence;

  /// Recognized language BCP-47 tag.
  final String? recognizedLanguage;

  const TextBlock({
    required this.text,
    this.lines = const [],
    this.boundingBox,
    this.confidence = 1.0,
    this.recognizedLanguage,
  });

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    Rect? box;
    if (json['boundingBox'] != null && json['boundingBox'] is Map) {
      final b = json['boundingBox'] as Map<String, dynamic>;
      box = Rect.fromLTWH(
        (b['left'] as num).toDouble(),
        (b['top'] as num).toDouble(),
        (b['width'] as num).toDouble(),
        (b['height'] as num).toDouble(),
      );
    }
    List<TextLine> lns = [];
    if (json['lines'] != null && json['lines'] is List) {
      lns = (json['lines'] as List)
          .map((l) => TextLine.fromJson(l as Map<String, dynamic>))
          .toList();
    }
    return TextBlock(
      text: json['text'] as String? ?? '',
      lines: lns,
      boundingBox: box,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      recognizedLanguage: json['recognizedLanguage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'lines': lines.map((l) => l.toJson()).toList(),
        'boundingBox': boundingBox != null
            ? {
                'left': boundingBox!.left,
                'top': boundingBox!.top,
                'width': boundingBox!.width,
                'height': boundingBox!.height,
              }
            : null,
        'confidence': confidence,
        'recognizedLanguage': recognizedLanguage,
      };

  @override
  String toString() => 'TextBlock("$text", lines: ${lines.length})';
}

/// Structured container holding full hierarchical OCR output (blocks, lines, elements).
class OcrTextResult {
  /// Unstructured full text extracted from the document.
  final String fullText;

  /// Hierarchical list of text blocks.
  final List<TextBlock> blocks;

  /// Overall OCR confidence score (0.0 to 1.0).
  final double overallConfidence;

  /// Primary detected script language (e.g. 'latin', 'devanagari').
  final String primaryLanguage;

  const OcrTextResult({
    required this.fullText,
    this.blocks = const [],
    this.overallConfidence = 0.98,
    this.primaryLanguage = 'latin',
  });

  /// Convenience getter for all lines across all blocks.
  List<TextLine> get lines =>
      blocks.expand((block) => block.lines).toList();

  /// Convenience getter for total word count.
  int get wordCount =>
      fullText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  factory OcrTextResult.fromJson(Map<String, dynamic> json) {
    List<TextBlock> blks = [];
    if (json['blocks'] != null && json['blocks'] is List) {
      blks = (json['blocks'] as List)
          .map((b) => TextBlock.fromJson(b as Map<String, dynamic>))
          .toList();
    }
    return OcrTextResult(
      fullText: json['fullText'] as String? ?? '',
      blocks: blks,
      overallConfidence: (json['overallConfidence'] as num?)?.toDouble() ?? 0.98,
      primaryLanguage: json['primaryLanguage'] as String? ?? 'latin',
    );
  }

  Map<String, dynamic> toJson() => {
        'fullText': fullText,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'overallConfidence': overallConfidence,
        'primaryLanguage': primaryLanguage,
        'wordCount': wordCount,
      };

  @override
  String toString() =>
      'OcrTextResult(blocks: ${blocks.length}, words: $wordCount, confidence: ${overallConfidence.toStringAsFixed(2)})';
}
