import 'package:flutter_test/flutter_test.dart';
import 'package:yummy_go_application/models/poll_model.dart';

void main() {
  group('PollResult & Voting Calculations', () {
    final options = ['Chicken Biryani', 'Pizza', 'Burger'];

    test('Zero votes scenario produces no winner and appropriate summary', () {
      final result = PollResult.calculate(
        options: options,
        votes: {},
      );

      expect(result.totalVotes, 0);
      expect(result.maxVotes, 0);
      expect(result.hasVotes, false);
      expect(result.isTie, false);
      expect(result.winningOption, isNull);
      expect(result.winningOptions, isEmpty);
      expect(result.resultSummary, 'No votes were cast before order placement.');
    });

    test('Single winner scenario correctly calculates winner and percentage', () {
      final votes = {
        'user_1': 0, // Biryani
        'user_2': 0, // Biryani
        'user_3': 1, // Pizza
      };

      final result = PollResult.calculate(
        options: options,
        votes: votes,
      );

      expect(result.totalVotes, 3);
      expect(result.maxVotes, 2);
      expect(result.hasVotes, true);
      expect(result.isTie, false);
      expect(result.winningOption, 'Chicken Biryani');
      expect(result.winningOptions, ['Chicken Biryani']);
      expect(result.winningIndices, [0]);
      expect(result.winningPercentage, 67); // (2/3 * 100).round()
      expect(result.resultSummary, contains('Winning Item: Chicken Biryani with 2 votes (67%)'));
    });

    test('Tied scenario correctly detects tie and lists tied options', () {
      final votes = {
        'user_1': 0, // Biryani
        'user_2': 0, // Biryani
        'user_3': 1, // Pizza
        'user_4': 1, // Pizza
      };

      final result = PollResult.calculate(
        options: options,
        votes: votes,
      );

      expect(result.totalVotes, 4);
      expect(result.maxVotes, 2);
      expect(result.hasVotes, true);
      expect(result.isTie, true);
      expect(result.winningOption, isNull);
      expect(result.winningOptions, ['Chicken Biryani', 'Pizza']);
      expect(result.winningIndices, [0, 1]);
      expect(result.winningPercentage, 50); // (2/4 * 100).round()
      expect(result.resultSummary, contains('Tied between Chicken Biryani & Pizza with 2 votes each (50%)'));
    });

    test('Multi-way tie with 3 options', () {
      final votes = {
        'user_1': 0, // Biryani
        'user_2': 1, // Pizza
        'user_3': 2, // Burger
      };

      final result = PollResult.calculate(
        options: options,
        votes: votes,
      );

      expect(result.totalVotes, 3);
      expect(result.maxVotes, 1);
      expect(result.isTie, true);
      expect(result.winningOptions, ['Chicken Biryani', 'Pizza', 'Burger']);
      expect(result.winningIndices, [0, 1, 2]);
    });

    test('Allowing members to change votes enforces strictly 1 active vote per user UID', () {
      final votes = <String, int>{
        'user_1': 0, // Biryani
        'user_2': 1, // Pizza
      };

      var result = PollResult.calculate(options: options, votes: votes);
      expect(result.totalVotes, 2);
      expect(result.counts[0], 1);
      expect(result.counts[1], 1);
      expect(result.isTie, true);

      // User 2 changes their vote to Biryani (option 0)
      votes['user_2'] = 0;

      result = PollResult.calculate(options: options, votes: votes);
      expect(result.totalVotes, 2, reason: 'Total votes must remain 2 after vote change');
      expect(result.counts[0], 2);
      expect(result.counts[1], 0);
      expect(result.isTie, false);
      expect(result.winningOption, 'Chicken Biryani');

      // User 1 changes their vote to Burger (option 2)
      votes['user_1'] = 2;

      result = PollResult.calculate(options: options, votes: votes);
      expect(result.totalVotes, 2);
      expect(result.counts[0], 1);
      expect(result.counts[1], 0);
      expect(result.counts[2], 1);
      expect(result.isTie, true);
      expect(result.winningOptions, ['Chicken Biryani', 'Burger']);
    });
  });

  group('PollModel', () {
    test('Constructs from map, retrieves voter names, and checks user vote', () {
      final map = {
        'groupId': 'group_123',
        'question': 'Dinner choice?',
        'options': ['Pasta', 'Sushi', 'Tacos'],
        'votes': {
          'uid_a': 1, // Sushi
          'uid_b': 1, // Sushi
          'uid_c': 0, // Pasta
        },
        'voterNames': {
          'uid_a': 'Alice',
          'uid_b': 'Bob',
          'uid_c': 'Charlie',
        },
        'createdBy': 'uid_a',
        'createdByName': 'Alice',
        'isClosed': false,
      };

      final poll = PollModel.fromMap('poll_abc', map);

      expect(poll.id, 'poll_abc');
      expect(poll.groupId, 'group_123');
      expect(poll.question, 'Dinner choice?');
      expect(poll.options.length, 3);
      expect(poll.userVoteIndex('uid_a'), 1);
      expect(poll.userVoteOption('uid_a'), 'Sushi');
      expect(poll.userVoteIndex('uid_unknown'), isNull);

      final sushiVoters = poll.getVoterNamesForOption(1);
      expect(sushiVoters, containsAll(['Alice', 'Bob']));

      final pastaVoters = poll.getVoterNamesForOption(0);
      expect(pastaVoters, contains('Charlie'));

      final tacosVoters = poll.getVoterNamesForOption(2);
      expect(tacosVoters, isEmpty);

      expect(poll.getVoteCount(1), 2);
      expect(poll.getPercentage(1), 67);

      expect(poll.result.winningOption, 'Sushi');
      expect(poll.result.isTie, false);
    });

    test('Serialization toMap preserves required Firestore properties', () {
      final poll = PollModel(
        id: 'poll_1',
        groupId: 'grp_1',
        question: 'Lunch?',
        options: ['Salad', 'Wrap'],
        votes: {'u1': 0},
        voterNames: {'u1': 'User 1'},
        createdBy: 'u1',
        createdByName: 'User 1',
        isClosed: true,
        closedReason: 'order_placed',
        savedWinner: 'Salad',
        savedWinningOptions: ['Salad'],
        savedIsTie: false,
      );

      final map = poll.toMap();
      expect(map['groupId'], 'grp_1');
      expect(map['isClosed'], true);
      expect(map['closedReason'], 'order_placed');
      expect(map['winningOption'], 'Salad');
      expect(map['winningOptions'], ['Salad']);
      expect(map['isTie'], false);
    });
  });
}

