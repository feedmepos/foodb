class OpenRevs {
  List<String> revs;
  bool all;

  OpenRevs({required this.revs, this.all = false});

  getOpenRevs() {
    if (all) {
      return "all";
    } else {
      return revs;
    }
  }
}
