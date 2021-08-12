class DesignDoc {
  String language;
  Map<String, DesignDocView> views;
}

class DesignDocView {
  ViewMapper map;
  ViewReducer reducer;
}

class ViewMapper {
  Map<String, String> fields;
  Map<String, String> partial_filter_selector;
}

class ViewReducer {
  String value;
}

class ViewOptions {
  ViewOptionsDef def;
}

class ViewOptionsDef {
  List<String> fields;
}
