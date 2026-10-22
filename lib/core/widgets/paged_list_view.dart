import 'package:flutter/material.dart';

/// Client-side paging for collections whose current API returns the complete
/// collection. Use server paging in repositories when the endpoint supports it.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 10,
    this.startAtEnd = false,
    this.previousLabel = 'Previous',
    this.nextLabel = 'Next',
    this.separatorBuilder,
    this.padding,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final bool startAtEnd;
  final String previousLabel;
  final String nextLabel;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.startAtEnd
        ? ((widget.items.length / widget.pageSize).ceil() - 1)
            .clamp(0, 1 << 30)
            .toInt()
        : 0;
  }

  @override
  void didUpdateWidget(covariant PagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = (widget.items.length / widget.pageSize).ceil() - 1;
    if (widget.startAtEnd && widget.items.length > oldWidget.items.length) {
      _page = lastPage.clamp(0, 1 << 30).toInt();
    } else if (_page > lastPage) {
      _page = lastPage.clamp(0, 1 << 30).toInt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageSize = widget.pageSize.clamp(1, 1000).toInt();
    final pageCount = (widget.items.length / pageSize).ceil();
    final start = _page * pageSize;
    final end = (start + pageSize).clamp(0, widget.items.length).toInt();
    final visible = widget.items.sublist(start.clamp(0, end).toInt(), end);
    return Column(children: [
      Expanded(
        child: ListView.separated(
          padding: widget.padding,
          itemCount: visible.length,
          separatorBuilder:
              widget.separatorBuilder ?? (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, visible[index], start + index),
        ),
      ),
      if (pageCount > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              label: Text(widget.previousLabel),
            ),
            const SizedBox(width: 12),
            Text('Page ${_page + 1} of $pageCount'),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed:
                  _page + 1 < pageCount ? () => setState(() => _page++) : null,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.nextLabel),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ]),
            ),
          ]),
        ),
    ]);
  }
}
