import 'package:flutter/material.dart';

// Weekend text colors meet WCAG AA 4.5:1 on every Daily surface of their
// brightness (#912).
Color calendarSundayAccent(Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0xfff87171)
    : const Color(0xffb91c1c);

Color calendarSaturdayAccent(Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0xff60a5fa)
    : const Color(0xff2563eb);

Color? calendarDateAccent(
  DateTime date, {
  required bool isHoliday,
  required int holidayColorValue,
  required Brightness brightness,
}) {
  if (isHoliday) return Color(holidayColorValue);
  if (date.weekday == DateTime.sunday) return calendarSundayAccent(brightness);
  if (date.weekday == DateTime.saturday) {
    return calendarSaturdayAccent(brightness);
  }
  return null;
}
