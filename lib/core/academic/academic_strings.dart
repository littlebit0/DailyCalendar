import 'package:flutter/widgets.dart';

enum AcademicText {
  title,
  school,
  categoryColor,
  year,
  preview,
  importSelected,
  refresh,
  automatic,
  source,
  unavailable,
  lastUpdated,
  never,
  selection,
  selectionNote,
  selectAll,
  disconnect,
  reconnect,
  remove,
  removeConfirm,
  cancel,
  result,
  preserved,
  failed,
  connected,
  show,
  yearRange,
}

String academicText(
  BuildContext context,
  AcademicText key, [
  Map<String, Object> args = const {},
]) {
  final index = switch (Localizations.localeOf(context).languageCode) {
    'ko' => 0,
    'ja' => 2,
    'zh' => 3,
    _ => 1,
  };
  var value = _strings[key]![index];
  for (final entry in args.entries) {
    value = value.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return value;
}

const _strings = <AcademicText, List<String>>{
  AcademicText.title: ['대학교 학사일정', 'University calendar', '大学の学年暦', '大學行事曆'],
  AcademicText.school: ['대학교', 'University', '大学', '大學'],
  AcademicText.categoryColor: ['분류 색상', 'Category color', '分類の色', '分類顏色'],
  AcademicText.year: ['연도', 'Year', '年', '年份'],
  AcademicText.preview: ['학사일정 확인', 'Preview calendar', '学年暦を確認', '預覽行事曆'],
  AcademicText.importSelected: [
    '선택한 일정 가져오기',
    'Import selected events',
    '選択した予定を取り込む',
    '匯入所選行程',
  ],
  AcademicText.refresh: ['지금 업데이트', 'Update now', '今すぐ更新', '立即更新'],
  AcademicText.automatic: [
    '자동 확인: 앱 실행·복귀 시 하루 1회',
    'Automatic check: once a day on launch or resume',
    '起動・復帰時に1日1回自動確認',
    '啟動或返回時每天自動檢查一次',
  ],
  AcademicText.source: ['공식 학사일정', 'Official calendar', '公式学年暦', '官方行事曆'],
  AcademicText.unavailable: [
    '학사일정을 불러오거나 저장하지 못했습니다. 기존 일정은 유지됩니다.',
    'Could not load or save the calendar. Existing events are kept.',
    '学年暦の取得または保存に失敗しました。既存の予定は保持されます。',
    '無法載入或儲存行事曆，既有行程會保留。',
  ],
  AcademicText.lastUpdated: [
    '마지막 업데이트: {date}',
    'Last updated: {date}',
    '最終更新: {date}',
    '最後更新：{date}',
  ],
  AcademicText.never: [
    '아직 업데이트되지 않음',
    'Not updated yet',
    'まだ更新されていません',
    '尚未更新',
  ],
  AcademicText.selection: [
    '가져올 일정 ({count})',
    'Events to import ({count})',
    '取り込む予定 ({count})',
    '要匯入的行程（{count}）',
  ],
  AcademicText.selectionNote: [
    '선택하지 않은 기존 일정은 그대로 남고 자동 갱신에서 제외됩니다.',
    'Existing unselected events are kept and excluded from automatic updates.',
    '選択しない既存の予定は保持し、自動更新から除外します。',
    '未選取的既有行程會保留，但不再自動更新。',
  ],
  AcademicText.selectAll: ['전체 선택', 'Select all', 'すべて選択', '全選'],
  AcademicText.disconnect: [
    '연동 해제 · 일정 유지',
    'Disconnect and keep events',
    '連携解除・予定を保持',
    '解除連結並保留行程',
  ],
  AcademicText.reconnect: [
    '자동 갱신 다시 연결',
    'Reconnect automatic updates',
    '自動更新を再接続',
    '重新連結自動更新',
  ],
  AcademicText.remove: [
    '가져온 일정 제거',
    'Remove imported events',
    '取り込んだ予定を削除',
    '移除匯入的行程',
  ],
  AcademicText.removeConfirm: [
    '이 대학에서 가져온 일정만 삭제하고 연동을 해제합니다. 개인 일정과 분류는 유지됩니다. 삭제는 연결된 기기에도 동기화됩니다.',
    'Delete only events imported from this university and disconnect. Personal events and categories are kept. Deletions sync to linked devices.',
    'この大学から取り込んだ予定のみ削除し、連携を解除します。個人の予定と分類は保持します。削除は連携端末にも同期されます。',
    '僅刪除此大學匯入的行程並解除連結。保留個人行程與分類，刪除會同步至已連結的裝置。',
  ],
  AcademicText.cancel: ['취소', 'Cancel', 'キャンセル', '取消'],
  AcademicText.result: [
    '추가 {added} · 갱신 {updated}',
    'Added {added} · Updated {updated}',
    '追加 {added}・更新 {updated}',
    '新增 {added}・更新 {updated}',
  ],
  AcademicText.preserved: [
    '사용자 변경·삭제 유지 {count}',
    'User edits/deletions preserved: {count}',
    'ユーザーの変更・削除を保持: {count}',
    '保留使用者修改或刪除：{count}',
  ],
  AcademicText.failed: [
    '저장 실패 {count} · 다시 업데이트해 주세요.',
    'Save failures: {count}. Please retry the update.',
    '保存失敗: {count}。再度更新してください。',
    '儲存失敗：{count}，請重試更新。',
  ],
  AcademicText.connected: [
    '연동된 학사일정',
    'Linked calendars',
    '連携中の学年暦',
    '已連結的行事曆',
  ],
  AcademicText.show: ['캘린더에 표시', 'Show in calendar', 'カレンダーに表示', '在日曆中顯示'],
  AcademicText.yearRange: [
    '{year}년 1월–12월 · 공식 제목·캠퍼스 구분 유지',
    'January–December {year} · Original titles and campus labels',
    '{year}年1月～12月・公式の名称とキャンパス表記を保持',
    '{year}年1月至12月・保留官方標題與校區標示',
  ],
};
