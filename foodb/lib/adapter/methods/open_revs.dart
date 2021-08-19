class OpenRevs {
  List<String> revs;
  bool all;

  OpenRevs._({this.revs = const [], this.all = false});

  factory OpenRevs.all() {
    return OpenRevs._(all: true);
  }

  factory OpenRevs.byRevs({required List<String> revs}) {
    return OpenRevs._(revs: revs);
  }

  getOpenRevs() {
    if (all) {
      return "all";
    } else {
      return revs;
    }
  }
}
