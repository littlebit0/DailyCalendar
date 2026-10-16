#include "../runner/widget_action_codec.h"
#include <cassert>
#include <sstream>
int main() {
  using namespace daily_widgets;
  const std::vector<TodoAction> actions = {
    {"tap", "series", true, "series@2026-10-15T09:00:00.000"},
    {"undo", "series", false, "series@2026-10-15T09:00:00.000"}
  };
  std::stringstream data;
  assert(WriteActions(data, actions));
  std::vector<TodoAction> loaded;
  assert(ReadActions(data, &loaded));
  assert(loaded.size() == 2 && loaded[0].occurrence_id == actions[0].occurrence_id);
  assert(loaded[0].event_id == "series" && !loaded[1].completed);
  std::stringstream legacy;
  legacy.write("DAILYAC1", 8);
  std::uint32_t one = 1;
  legacy.write(reinterpret_cast<const char*>(&one), sizeof(one));
  assert(WriteString(legacy, "legacy-token") && WriteString(legacy, "series"));
  legacy.put(1);
  assert(ReadActions(legacy, &loaded));
  assert(loaded.size() == 1 && loaded[0].occurrence_id.empty());
  const auto bytes = data.str();
  for (std::size_t length = 0; length < bytes.size(); ++length) {
    std::stringstream truncated(bytes.substr(0, length));
    assert(!ReadActions(truncated, &loaded));
    assert(loaded[0].token == "legacy-token");
  }
}
