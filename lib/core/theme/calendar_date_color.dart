import 'package:flutter/material.dart';

Color? calendarDateAccent(
  DateTime date, {
  required bool isHoliday,
  required int holidayColorValue,
}) {
  if (isHoliday) return Color(holidayColorValue);
  if (date.weekday == DateTime.sunday) return const Color(0xffef4444);
  if (date.weekday == DateTime.saturday) return const Color(0xff2563eb);
  return null;
}
