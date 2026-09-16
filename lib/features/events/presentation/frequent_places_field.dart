import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/calendar_event.dart';
import '../domain/frequent_places.dart';

class FrequentPlacesField extends StatefulWidget {
  const FrequentPlacesField({
    super.key,
    required this.store,
    required this.loadEvents,
    required this.controller,
  });
  final FrequentPlaces store;
  final Future<List<CalendarEvent>> Function() loadEvents;
  final TextEditingController controller;
  @override
  State<FrequentPlacesField> createState() => _FrequentPlacesFieldState();
}

class _FrequentPlacesFieldState extends State<FrequentPlacesField> {
  List<CalendarEvent> _events = [];
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await widget.loadEvents();
      if (mounted) {
        setState(() {
          _events = events;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _manage() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PlaceManager(
        store: widget.store,
        events: _events,
        initial: widget.controller.text,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.store.recommend(_events);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(
            labelText: context.tr('장소'),
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: IconButton(
              onPressed: _manage,
              tooltip: context.tr('장소 관리'),
              icon: const Icon(Icons.edit_location_alt_outlined),
            ),
          ),
        ),
        if (places.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: places
                  .map(
                    (place) => ActionChip(
                      avatar: widget.store.pinned.contains(place)
                          ? const Icon(Icons.push_pin, size: 16)
                          : null,
                      label: Text(place, overflow: TextOverflow.ellipsis),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        widget.controller.text = place;
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_failed)
          TextButton(
            onPressed: _load,
            child: Text(context.tr('장소 추천을 불러오지 못했습니다. 다시 시도')),
          ),
      ],
    );
  }
}

class _PlaceManager extends StatefulWidget {
  const _PlaceManager({
    required this.store,
    required this.events,
    required this.initial,
  });
  final FrequentPlaces store;
  final List<CalendarEvent> events;
  final String initial;
  @override
  State<_PlaceManager> createState() => _PlaceManagerState();
}

class _PlaceManagerState extends State<_PlaceManager> {
  late final _input = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) _error = context.tr('다시 시도');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: ListView(
            children: [
              Text(
                context.tr('장소 관리'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('자동 장소 추천')),
                value: store.automatic,
                onChanged: _busy
                    ? null
                    : (value) => _save(() => store.update(automatic: value)),
              ),
              TextField(
                controller: _input,
                decoration: InputDecoration(
                  labelText: context.tr('장소'),
                  suffixIcon: IconButton(
                    tooltip: context.tr('장소 고정'),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    onPressed: _busy
                        ? null
                        : () => _save(
                            () => store.update(
                              pinned: [...store.pinned, _input.text],
                            ),
                          ),
                  ),
                ),
              ),
              if (_error != null) Text(_error!),
              for (final place in store.recommend(widget.events, limit: 50))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(place),
                  leading: IconButton(
                    tooltip: context.tr(
                      store.pinned.contains(place) ? '고정 해제' : '장소 고정',
                    ),
                    icon: Icon(
                      store.pinned.contains(place)
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _save(
                            () => store.update(
                              pinned: store.pinned.contains(place)
                                  ? (store.pinned..remove(place))
                                  : [...store.pinned, place],
                            ),
                          ),
                  ),
                  trailing: IconButton(
                    tooltip: context.tr('숨기기'),
                    icon: const Icon(Icons.visibility_off_outlined),
                    onPressed: _busy
                        ? null
                        : () => _save(
                            () => store.update(
                              pinned: store.pinned..remove(place),
                              hidden: [...store.hidden, place],
                            ),
                          ),
                  ),
                ),
              if (store.hidden.isNotEmpty)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _save(() => store.update(hidden: [])),
                  child: Text(context.tr('숨긴 장소 다시 표시')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
