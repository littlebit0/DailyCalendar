#ifndef DAILY_WIDGET_ACTION_CODEC_H_
#define DAILY_WIDGET_ACTION_CODEC_H_
#include <algorithm>
#include <array>
#include <cstdint>
#include <istream>
#include <ostream>
#include <string>
#include <vector>

namespace daily_widgets {
struct TodoAction {
  std::string token;
  std::string event_id;
  bool completed = false;
  std::string occurrence_id;
};
inline constexpr char kMagic[] = {'D', 'A', 'I', 'L', 'Y', 'A', 'C', '2'};
inline constexpr std::size_t kMaxActions = 4096;
inline constexpr std::uint32_t kMaxStringBytes = 64 * 1024;
inline bool WriteString(std::ostream& out, const std::string& value) {
  if (value.size() > kMaxStringBytes) return false;
  const auto size = static_cast<std::uint32_t>(value.size());
  out.write(reinterpret_cast<const char*>(&size), sizeof(size));
  out.write(value.data(), static_cast<std::streamsize>(size));
  return out.good();
}
inline bool ReadString(std::istream& in, std::string* value) {
  std::uint32_t size = 0;
  in.read(reinterpret_cast<char*>(&size), sizeof(size));
  if (!in.good() || size > kMaxStringBytes) return false;
  value->resize(size);
  in.read(value->data(), static_cast<std::streamsize>(size));
  return in.good();
}
inline bool ReadActions(std::istream& in, std::vector<TodoAction>* destination) {
  std::array<char, sizeof(kMagic)> magic{};
  in.read(magic.data(), static_cast<std::streamsize>(magic.size()));
  if (!in.good() || !std::equal(magic.begin(), magic.end() - 1, std::begin(kMagic)) ||
      (magic.back() != '1' && magic.back() != '2')) return false;
  std::uint32_t count = 0;
  in.read(reinterpret_cast<char*>(&count), sizeof(count));
  if (!in.good() || count > kMaxActions) return false;
  std::vector<TodoAction> loaded;
  for (std::uint32_t index = 0; index < count; ++index) {
    TodoAction action;
    std::uint8_t complete = 0;
    if (!ReadString(in, &action.token) || !ReadString(in, &action.event_id)) return false;
    in.read(reinterpret_cast<char*>(&complete), sizeof(complete));
    if (!in.good() || complete > 1) return false;
    action.completed = complete != 0;
    if (magic.back() == '2' && !ReadString(in, &action.occurrence_id)) return false;
    loaded.push_back(std::move(action));
  }
  *destination = std::move(loaded);
  return true;
}
inline bool WriteActions(std::ostream& out, const std::vector<TodoAction>& actions) {
  if (actions.size() > kMaxActions) return false;
  out.write(kMagic, sizeof(kMagic));
  const auto count = static_cast<std::uint32_t>(actions.size());
  out.write(reinterpret_cast<const char*>(&count), sizeof(count));
  for (const auto& action : actions) {
    if (!WriteString(out, action.token) || !WriteString(out, action.event_id)) return false;
    const std::uint8_t completed = action.completed ? 1 : 0;
    out.write(reinterpret_cast<const char*>(&completed), sizeof(completed));
    if (!WriteString(out, action.occurrence_id)) return false;
  }
  return out.good();
}
}  // namespace daily_widgets
#endif
