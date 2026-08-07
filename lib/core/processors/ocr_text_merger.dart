import 'dart:math' as math;

/// Confidence-weighted multi-pass OCR text merger.
///
/// Merges results from multiple OCR passes (original, CLAHE-enhanced,
/// binarized) into a single high-confidence text output using
/// character-level voting and block-level spatial deduplication.
///
/// Inspired by Tesseract's multi-pass approach and Dynamsoft's
/// confidence-weighted text fusion.
class OcrTextMerger {
  /// Merges multiple OCR pass results into a single best-confidence output.
  ///
  /// [passes] — List of OCR pass results with their preprocessing context.
  ///
  /// Returns a [MergedOcrResult] with the best-confidence text and per-block scores.
  static MergedOcrResult merge(List<OcrPassResult> passes) {
    if (passes.isEmpty) {
      return const MergedOcrResult(
        text: '',
        confidence: 0.0,
        blockConfidences: [],
        passesUsed: 0,
        mergeStrategy: 'empty',
      );
    }

    if (passes.length == 1) {
      return MergedOcrResult(
        text: passes[0].text,
        confidence: passes[0].confidence,
        blockConfidences: [passes[0].confidence],
        passesUsed: 1,
        mergeStrategy: 'single_pass',
      );
    }

    // Strategy 1: If passes agree closely, use highest-confidence pass
    final bestPass = passes.reduce((a, b) => a.confidence > b.confidence ? a : b);
    final agreement = _computeAgreement(passes);

    if (agreement > 0.95) {
      return MergedOcrResult(
        text: bestPass.text,
        confidence: math.min(1.0, bestPass.confidence * 1.05), // Boost for agreement
        blockConfidences: [bestPass.confidence],
        passesUsed: passes.length,
        mergeStrategy: 'consensus_highest',
      );
    }

    // Strategy 2: Line-level voting and merging
    final mergedLines = _mergeByLines(passes);

    return MergedOcrResult(
      text: mergedLines.text,
      confidence: mergedLines.confidence,
      blockConfidences: mergedLines.lineConfidences,
      passesUsed: passes.length,
      mergeStrategy: 'line_level_voting',
    );
  }

  /// Computes agreement ratio between multiple OCR passes.
  ///
  /// Uses Levenshtein distance normalized by text length.
  /// Returns 1.0 for identical texts, 0.0 for completely different.
  static double _computeAgreement(List<OcrPassResult> passes) {
    if (passes.length < 2) return 1.0;

    double totalSimilarity = 0;
    int comparisons = 0;

    for (int i = 0; i < passes.length; i++) {
      for (int j = i + 1; j < passes.length; j++) {
        totalSimilarity += _stringSimilarity(passes[i].text, passes[j].text);
        comparisons++;
      }
    }

    return comparisons > 0 ? totalSimilarity / comparisons : 1.0;
  }

  /// Line-level merging: splits each pass into lines, then votes on
  /// the best version of each line.
  static _LineMergeResult _mergeByLines(List<OcrPassResult> passes) {
    // Split all passes into lines
    final allLines = passes.map((p) => _splitIntoLines(p)).toList();

    // Determine the maximum number of lines across all passes
    final maxLines = allLines.map((l) => l.length).reduce(math.max);

    final mergedLines = <String>[];
    final lineConfidences = <double>[];

    for (int lineIdx = 0; lineIdx < maxLines; lineIdx++) {
      // Collect all versions of this line from each pass
      final candidates = <_LineCandidate>[];
      for (int passIdx = 0; passIdx < allLines.length; passIdx++) {
        if (lineIdx < allLines[passIdx].length) {
          candidates.add(_LineCandidate(
            text: allLines[passIdx][lineIdx],
            confidence: passes[passIdx].confidence,
            passWeight: passes[passIdx].weight,
          ));
        }
      }

      if (candidates.isEmpty) continue;

      // Vote: pick the candidate with highest weighted confidence
      // If multiple candidates are very similar, merge character-by-character
      final bestCandidate = _selectBestLine(candidates);
      mergedLines.add(bestCandidate.text);
      lineConfidences.add(bestCandidate.confidence);
    }

    final fullText = mergedLines.join('\n');
    final avgConfidence = lineConfidences.isEmpty
        ? 0.0
        : lineConfidences.reduce((a, b) => a + b) / lineConfidences.length;

    return _LineMergeResult(
      text: fullText,
      confidence: avgConfidence,
      lineConfidences: lineConfidences,
    );
  }

  /// Selects the best version of a line from multiple candidates.
  static _LineCandidate _selectBestLine(List<_LineCandidate> candidates) {
    if (candidates.length == 1) return candidates[0];

    // Score each candidate by weighted confidence and agreement with others
    double bestScore = -1;
    _LineCandidate bestCandidate = candidates[0];

    for (final candidate in candidates) {
      double agreementScore = 0;
      for (final other in candidates) {
        if (other != candidate) {
          agreementScore += _stringSimilarity(candidate.text, other.text);
        }
      }
      agreementScore /= (candidates.length - 1);

      // Combined score: own confidence × pass weight × agreement with others
      final score = candidate.confidence * candidate.passWeight * (0.5 + 0.5 * agreementScore);

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    // If best candidate has low agreement, try character-level merging
    if (bestScore < 0.5 && candidates.length >= 2) {
      final merged = _characterLevelMerge(candidates);
      if (merged != null) return merged;
    }

    return bestCandidate;
  }

  /// Character-level merge: for each position, vote on the most common character.
  static _LineCandidate? _characterLevelMerge(List<_LineCandidate> candidates) {
    final maxLen = candidates.map((c) => c.text.length).reduce(math.max);
    if (maxLen == 0) return null;

    final buffer = StringBuffer();
    double totalConfidence = 0;

    for (int pos = 0; pos < maxLen; pos++) {
      final charVotes = <String, double>{};

      for (final candidate in candidates) {
        if (pos < candidate.text.length) {
          final ch = candidate.text[pos];
          charVotes[ch] = (charVotes[ch] ?? 0) + candidate.confidence * candidate.passWeight;
        }
      }

      if (charVotes.isEmpty) continue;

      // Pick character with highest vote weight
      String bestChar = ' ';
      double bestWeight = 0;
      charVotes.forEach((ch, weight) {
        if (weight > bestWeight) {
          bestWeight = weight;
          bestChar = ch;
        }
      });

      buffer.write(bestChar);
      totalConfidence += bestWeight;
    }

    final text = buffer.toString();
    final avgConf = maxLen > 0 ? totalConfidence / maxLen : 0.0;

    return _LineCandidate(
      text: text,
      confidence: avgConf.clamp(0.0, 1.0),
      passWeight: 1.0,
    );
  }

  /// Splits OCR pass text into lines, filtering empty lines.
  static List<String> _splitIntoLines(OcrPassResult pass) {
    return pass.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Computes string similarity using Levenshtein distance.
  /// Returns 1.0 for identical, 0.0 for completely different.
  static double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final maxLen = math.max(a.length, b.length);
    final distance = _levenshteinDistance(a, b);
    return 1.0 - (distance / maxLen);
  }

  /// Levenshtein edit distance between two strings.
  static int _levenshteinDistance(String a, String b) {
    final la = a.length;
    final lb = b.length;

    // Optimize: use single row + previous value instead of full matrix
    var prev = List<int>.generate(lb + 1, (i) => i);
    var curr = List<int>.filled(lb + 1, 0);

    for (int i = 1; i <= la; i++) {
      curr[0] = i;
      for (int j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost, // substitution
        ].reduce(math.min);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[lb];
  }
}

/// Input for a single OCR pass.
class OcrPassResult {
  /// Recognized text from this pass.
  final String text;

  /// Confidence score (0.0–1.0).
  final double confidence;

  /// Name of the preprocessing applied before this pass.
  final String preprocessingName;

  /// Weight multiplier for this pass in voting (higher = more trusted).
  final double weight;

  const OcrPassResult({
    required this.text,
    required this.confidence,
    required this.preprocessingName,
    this.weight = 1.0,
  });
}

/// Result of multi-pass OCR merging.
class MergedOcrResult {
  /// Merged best-confidence text.
  final String text;

  /// Overall merged confidence (0.0–1.0).
  final double confidence;

  /// Per-block/line confidence scores.
  final List<double> blockConfidences;

  /// Number of OCR passes used in merging.
  final int passesUsed;

  /// Name of the merge strategy applied.
  final String mergeStrategy;

  const MergedOcrResult({
    required this.text,
    required this.confidence,
    required this.blockConfidences,
    required this.passesUsed,
    required this.mergeStrategy,
  });
}

class _LineCandidate {
  final String text;
  final double confidence;
  final double passWeight;

  const _LineCandidate({
    required this.text,
    required this.confidence,
    required this.passWeight,
  });
}

class _LineMergeResult {
  final String text;
  final double confidence;
  final List<double> lineConfidences;

  const _LineMergeResult({
    required this.text,
    required this.confidence,
    required this.lineConfidences,
  });
}
