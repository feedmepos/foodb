import 'package:foodb/common/rev.dart';

class UpdateSequence {
  String seq;
  String id;
  Rev winnerRev;
  List<Rev> allLeafRev;
  UpdateSequence({
    required this.seq,
    required this.id,
    required this.winnerRev,
    required this.allLeafRev,
  });

  factory UpdateSequence.fromJson(Map<String, dynamic> json) => UpdateSequence(
        seq: json['seq'] as String,
        id: json['id'] as String,
        winnerRev: Rev.fromString(json['winnerRev'] as String),
        allLeafRev: (json['allLeafRev'] as List<dynamic>)
            .map((e) => Rev.fromString(e as String))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'seq': this.seq,
        'id': this.id,
        'winnerRev': this.winnerRev.toString(),
        'allLeafRev': this.allLeafRev.map((e) => e.toString()),
      };
}
