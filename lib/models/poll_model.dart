import 'package:cloud_firestore/cloud_firestore.dart';

/// Encapsulates the calculated results of a group voting poll.
/// Supports single winners, tied options, and zero-vote scenarios.
class PollResult {
  final int totalVotes;
  final int maxVotes;
  final List<int> counts;
  final bool hasVotes;
  final bool isTie;
  final String? winningOption;
  final List<String> winningOptions;
  final List<int> winningIndices;
  final String resultSummary;

  const PollResult({
    required this.totalVotes,
    required this.maxVotes,
    required this.counts,
    required this.hasVotes,
    required this.isTie,
    this.winningOption,
    required this.winningOptions,
    required this.winningIndices,
    required this.resultSummary,
  });

  int get winningPercentage =>
      totalVotes == 0 ? 0 : ((maxVotes / totalVotes) * 100).round();

  /// Calculates vote tally and determines winning food item or tied options.
  static PollResult calculate({
    required List<String> options,
    required Map<dynamic, dynamic> votes,
  }) {
    final counts = List<int>.filled(options.length, 0);
    int total = 0;

    for (final entry in votes.entries) {
      final rawIdx = entry.value;
      final idx = rawIdx is int ? rawIdx : int.tryParse(rawIdx.toString());
      if (idx != null && idx >= 0 && idx < options.length) {
        counts[idx]++;
        total++;
      }
    }

    if (total == 0 || options.isEmpty) {
      return PollResult(
        totalVotes: 0,
        maxVotes: 0,
        counts: counts,
        hasVotes: false,
        isTie: false,
        winningOption: null,
        winningOptions: const [],
        winningIndices: const [],
        resultSummary: 'No votes were cast before order placement.',
      );
    }

    int maxV = 0;
    for (final c in counts) {
      if (c > maxV) maxV = c;
    }

    final winningIndices = <int>[];
    final winningOptions = <String>[];
    for (int i = 0; i < options.length; i++) {
      if (counts[i] == maxV) {
        winningIndices.add(i);
        winningOptions.add(options[i]);
      }
    }

    final isTie = winningIndices.length > 1;
    final winningOption = isTie ? null : winningOptions.first;
    final pct = ((maxV / total) * 100).round();

    final String summary;
    if (isTie) {
      final items = winningOptions.join(' & ');
      summary = 'Tied between $items with $maxV ${maxV == 1 ? 'vote' : 'votes'} each ($pct%)';
    } else {
      summary = 'Winning Item: $winningOption with $maxV ${maxV == 1 ? 'vote' : 'votes'} ($pct%)';
    }

    return PollResult(
      totalVotes: total,
      maxVotes: maxV,
      counts: counts,
      hasVotes: true,
      isTie: isTie,
      winningOption: winningOption,
      winningOptions: winningOptions,
      winningIndices: winningIndices,
      resultSummary: summary,
    );
  }
}

/// Represents a group food voting poll in Firestore under `group_orders/{groupId}/polls/{pollId}`.
/// Enforces 1 active vote per user UID and remains active until group order placement.
class PollModel {
  final String id;
  final String groupId;
  final String question;
  final List<String> options;
  final Map<String, int> votes; // Firebase UID -> optionIndex (strictly 1 active vote per UID)
  final Map<String, String> voterNames; // Firebase UID -> member display name
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final bool isClosed;
  final DateTime? closedAt;
  final String? closedReason;
  final String? savedWinner;
  final List<String> savedWinningOptions;
  final bool? savedIsTie;

  PollModel({
    required this.id,
    required this.groupId,
    required this.question,
    required this.options,
    required this.votes,
    required this.voterNames,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.isClosed = false,
    this.closedAt,
    this.closedReason,
    this.savedWinner,
    this.savedWinningOptions = const [],
    this.savedIsTie,
  });

  /// Dynamically computes the latest or final tally, winner, or ties.
  PollResult get result => PollResult.calculate(options: options, votes: votes);

  /// Returns the option index voted by [uid], or null if not yet voted.
  int? userVoteIndex(String? uid) {
    if (uid == null || !votes.containsKey(uid)) return null;
    final idx = votes[uid];
    if (idx != null && idx >= 0 && idx < options.length) return idx;
    return null;
  }

  /// Returns the text of the option voted by [uid], or null.
  String? userVoteOption(String? uid) {
    final idx = userVoteIndex(uid);
    if (idx != null) return options[idx];
    return null;
  }

  /// Returns the display names of all members who voted for [optionIndex].
  List<String> getVoterNamesForOption(int optionIndex) {
    final names = <String>[];
    for (final entry in votes.entries) {
      if (entry.value == optionIndex) {
        final name = voterNames[entry.key]?.trim();
        if (name != null && name.isNotEmpty) {
          names.add(name);
        }
      }
    }
    return names;
  }

  /// Returns the vote count for [optionIndex].
  int getVoteCount(int optionIndex) {
    if (optionIndex < 0 || optionIndex >= options.length) return 0;
    int count = 0;
    for (final v in votes.values) {
      if (v == optionIndex) count++;
    }
    return count;
  }

  /// Returns the vote percentage (0 - 100) for [optionIndex].
  int getPercentage(int optionIndex) {
    final total = votes.length;
    if (total == 0) return 0;
    return ((getVoteCount(optionIndex) / total) * 100).round();
  }

  factory PollModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PollModel.fromMap(doc.id, data);
  }

  factory PollModel.fromMap(String docId, Map<String, dynamic> data) {
    final rawOptions = data['options'] as List<dynamic>? ?? const [];
    final options = rawOptions.map((e) => e.toString().trim()).toList();

    final rawVotes = data['votes'];
    final votes = <String, int>{};
    if (rawVotes is Map) {
      for (final entry in rawVotes.entries) {
        final key = entry.key.toString();
        final rawVal = entry.value;
        final intVal = rawVal is int ? rawVal : int.tryParse(rawVal.toString());
        if (intVal != null) {
          votes[key] = intVal;
        }
      }
    }

    final rawNames = data['voterNames'];
    final voterNames = <String, String>{};
    if (rawNames is Map) {
      for (final entry in rawNames.entries) {
        voterNames[entry.key.toString()] = entry.value.toString();
      }
    }

    DateTime? createdAt;
    final rawCreated = data['createdAt'] ?? data['clientCreatedAt'];
    if (rawCreated is Timestamp) {
      createdAt = rawCreated.toDate();
    } else if (rawCreated is DateTime) {
      createdAt = rawCreated;
    }

    DateTime? closedAt;
    final rawClosed = data['closedAt'];
    if (rawClosed is Timestamp) {
      closedAt = rawClosed.toDate();
    } else if (rawClosed is DateTime) {
      closedAt = rawClosed;
    }

    final rawWinOptions = data['winningOptions'] as List<dynamic>? ?? const [];
    final winningOptions = rawWinOptions.map((e) => e.toString().trim()).toList();

    return PollModel(
      id: docId,
      groupId: data['groupId']?.toString() ?? '',
      question: data['question']?.toString().trim().isNotEmpty == true
          ? data['question'].toString().trim()
          : 'What should we order?',
      options: options,
      votes: votes,
      voterNames: voterNames,
      createdBy: data['createdBy']?.toString() ?? '',
      createdByName: data['createdByName']?.toString().trim().isNotEmpty == true
          ? data['createdByName'].toString().trim()
          : 'Member',
      createdAt: createdAt,
      isClosed: data['isClosed'] == true,
      closedAt: closedAt,
      closedReason: data['closedReason']?.toString(),
      savedWinner: data['winningOption']?.toString() ?? data['winner']?.toString(),
      savedWinningOptions: winningOptions,
      savedIsTie: data['isTie'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'question': question,
      'options': options,
      'votes': votes,
      'voterNames': voterNames,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'isClosed': isClosed,
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
      if (closedReason != null) 'closedReason': closedReason,
      if (savedWinner != null) 'winningOption': savedWinner,
      if (savedWinningOptions.isNotEmpty) 'winningOptions': savedWinningOptions,
      if (savedIsTie != null) 'isTie': savedIsTie,
    };
  }
}

