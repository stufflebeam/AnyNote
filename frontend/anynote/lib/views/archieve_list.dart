import 'dart:async';
import 'dart:ui';
import 'package:anynote/views/markdown_render/markdown_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:anynote/MainController.dart';
import 'package:anynote/note_api_service.dart';
import 'package:anynote/views/EditNote.dart';
import 'package:anynote/Extension.dart';
import 'package:intl/intl.dart' as intl;

class ArchiveList extends StatefulWidget {
  ArchiveList({Key? key, this.isArchive = false}) : super(key: key);

  final bool isArchive;

  @override
  _ArchiveListState createState() => _ArchiveListState();
}

class _ArchiveListState extends State<ArchiveList> {
  final MainController controller = Get.find<MainController>();
  final ScrollController sc = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    controller.updateFilter('');
  }

  @override
  void dispose() {
    //controller.updateFilter('');
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isArchive) _buildSearchBar(),
        Expanded(
          child: Obx(() {
            var archivedNotes = widget.isArchive
                ? controller.filteredArchivedNotes
                : controller.filteredUnarchivedNotes;
            return Scrollbar(
              controller: sc,
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(
                  scrollbars: false,
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await controller.fetchNotes();
                    } catch (e) {
                      // Handle error, e.g., show a SnackBar
                    }
                  },
                  child: _buildList(archivedNotes, widget.isArchive),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildList(List<NoteItem> archivedNotes, bool isArchive) {

    int _calculateItemCount(List<NoteItem> archivedNotes) {
      final topmostCount = archivedNotes.where((item) => item.isTopMost).length;
      final normalCount = archivedNotes.length - topmostCount;
      int itemCount = 0;

      if (topmostCount > 0) {
        itemCount += 1 + topmostCount; // Header + items
      }
      if (normalCount > 0) {
        itemCount += 1 + normalCount; // Header + items
      }
      return itemCount;
    }

    Widget _buildHeader(String title, {double topPadding = 10.0}) {
      return Padding(
        padding: EdgeInsets.only(left: 8, right: 8, top: topPadding, bottom: 0),
        child: Row(
          children: [
            Text(
              title,
              style:  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.black87),
            ),
          ],
        ),
      );
    }

    Widget _buildItem(NoteItem item) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeAgo(item.createTime),
              style: const TextStyle(fontSize: 10, color: Colors.black38),
            ),
            const SizedBox(height: 3),
            NoteItemWidget(
              key: ValueKey(item.id),
              controller: controller,
              item: item,
              isArchive: isArchive,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      controller: sc,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: _calculateItemCount(archivedNotes),
      itemBuilder: (BuildContext context, int index) {
        final topmostItems = archivedNotes.where((item) => item.isTopMost).toList();
        final normalItems = archivedNotes.where((item) => !item.isTopMost).toList();

        int currentIndex = index;

        // Check if we're displaying the "Topmost" header
        if (topmostItems.isNotEmpty) {
          if (currentIndex == 0) {
            return _buildHeader("📌 Topmost");
          }
          currentIndex--;

          // Display topmost items
          if (currentIndex < topmostItems.length) {
            final item = topmostItems[currentIndex];
            return _buildItem(item);
          }
          currentIndex -= topmostItems.length;
        }

        // Check if we're displaying the "Notes" header
        if (normalItems.isNotEmpty) {
          if (currentIndex == 0) {
            // Adjust the top padding based on the presence of topmost items
            final double topPadding = topmostItems.isNotEmpty ? 30.0 : 10.0;
            return _buildHeader("🗒️ Notes", topPadding: topPadding);
          }
          currentIndex--;

          // Display normal items
          if (currentIndex < normalItems.length) {
            final item = normalItems[currentIndex];
            return _buildItem(item);
          }
        }

        return const SizedBox.shrink(); // Fallback for any unexpected indices
      },
    );


  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
      child: TextField(
        style: const TextStyle(fontSize: 12),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          fillColor: Colors.white.withOpacity(0.6),
          filled: true,
          hintText: "Search...",
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(width: 1, color: Colors.black54),
            borderRadius: BorderRadius.circular(0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(width: 1, color: Colors.black12),
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      controller.updateFilter(query);
    });
  }
}

class NoteItemWidget extends StatefulWidget {
  final MainController controller;
  final NoteItem item;
  final bool isArchive;

  const NoteItemWidget({
    super.key,
    required this.controller,
    required this.item,
    required this.isArchive,
  });

  @override
  State<NoteItemWidget> createState() => _NoteItemWidgetState();
}

class _NoteItemWidgetState extends State<NoteItemWidget> {
  bool _isOverflow = false;
  bool _isHovered = false;
  final ScrollController _scrollController = ScrollController();
  final MainController c = Get.find<MainController>();
  @override
  void initState() {
    super.initState();
    _checkOverflow();
  }

  @override
  void didUpdateWidget(NoteItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkOverflow();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isOverflow = _scrollController.position.maxScrollExtent > 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(widget.item.id),
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color:darkenColor(widget.item.color.toFullARGB()),blurRadius: 2)],
        border: Border.all(
          color: _isHovered
              ? darkenColor(widget.item.color.toFullARGB(), 0.3)
              : darkenColor(widget.item.color.toFullARGB(), 0.1),
          width: 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(5))

      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: widget.item.color.toFullARGB(),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            //behavior: HitTestBehavior.translucent,
            onTap: () async {
              await Get.to(() => EditNotePage(item: widget.item));
            },
            onTapDown: (_) => setState(() => _isHovered = true),
            onTapUp: (_) => setState(() => _isHovered = false),
            onTapCancel: () => setState(() => _isHovered = false),
            onLongPress: ()async{var res= await _showOptionsDialog(widget.item);
                  switch (res) {
                    case 'toggleTopMost':
                      widget.item.isTopMost = !widget.item.isTopMost;
                      widget.controller.updateNote(widget.item.id!, widget.item);
                      break;
                    case 'toggleArchive':
                      if (widget.isArchive) {
                        widget.controller.unarchiveNote(widget.item.id!);
                      } else {
                        widget.controller.archiveNote(widget.item.id!);
                      }
                      break;
                    case 'copy':
                      Clipboard.setData(
                          ClipboardData(text: widget.item.content ?? ""));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied'),backgroundColor: Colors.green,),
                      );
                      break;
                    case 'delete':
                      widget.controller.deleteNote(widget.item.id!);
                      break;
                    case 'up':
                      var list = widget.controller.filteredUnarchivedNotes;
                      int index = list.indexWhere((obj) => obj.id == widget.item.id);
                      // 如果找到了且该元素不是第一个元素
                      if (index > 0) {
                        // 交换当前元素和它前面的一个元素的位置
                        var temp = list[index - 1];
                        list[index - 1] = list[index];
                        list[index] = temp;
                      }

                      widget.controller.updateIndex(list);

                      break;
                    case 'down':
                      var list = widget.controller.filteredUnarchivedNotes;
                      int index = list.indexWhere((obj) => obj.id == widget.item.id);

                      if(index==list.length-1)break;

                      // 如果找到了且该元素不是第一个元素
                      if (index > -1) {
                        // 交换当前元素和它前面的一个元素的位置
                        var temp = list[index + 1];
                        list[index + 1] = list[index];
                        list[index] = temp;
                      }
                      widget.controller.updateIndex(list);
                      break;
                  }
              },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                //_buildHeader(context),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return _buildContent(constraints);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BoxConstraints constraints) {

    var content= SingleChildScrollView(
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
        child: Obx(() {
          return MarkdownRenderer(
            fontsize: c.fontSize.value,
            data: widget.item.content?.trimRight() ?? "",
          );
        }),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Stack(
            children: [
              if(widget.item.isTopMost)
                const Positioned(right: 0, top: 0, child: Icon(Icons.vertical_align_top,size: 20,color: Colors.orange, )),

              _isOverflow?
              ShaderMask(
                shaderCallback: (Rect bounds) {
                return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black,Colors.transparent],
                stops: [0.0, 0.6,1],
                ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: content,
              ):content,

              if (_isOverflow)
                Positioned(
                  bottom: -5,
                  left: 1 / 2,
                  right: 0,
                  child: Icon(
                    Icons.more_horiz,
                    color: darkenColor(widget.item.color.toFullARGB(), 0.55),
                    size: 20,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _isHovered?darkenColor(widget.item.color.toFullARGB(), 0.1):darkenColor(widget.item.color.toFullARGB(), 0.04),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          if (widget.item.isTopMost)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.star,
                color: Colors.orange,
                size: 15,
              ),
            ),
          Text(
            timeAgo(widget.item.createTime),
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Future<String?> _showOptionsDialog(NoteItem item) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Options',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 显示创建时间和最后更新时间
              // Text(
              //   'Created: ${timeAgo(item.createTime!)}',
              //   style: TextStyle(color: Colors.grey[600], fontSize: 10),
              // ),

              const SizedBox(height: 10,),

              ListTile(
                leading: Icon(
                  item.isTopMost ? Icons.star : Icons.star_border,
                  color: item.isTopMost ? Colors.orange : Colors.grey,
                ),
                title: Text(
                  item.isTopMost ? 'Remove from Top' : 'Add to Top',
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () => Navigator.of(context).pop('toggleTopMost'),
              ),

              if(!widget.isArchive)
                ListTile(
                  leading: const Icon(
                    Icons.arrow_upward
                  ),
                  title: const Text(
                    "Move Up",
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () => Navigator.of(context).pop('up'),
                ),

              if(!widget.isArchive)
                ListTile(
                  leading: const Icon(
                      Icons.arrow_downward
                  ),
                  title: const Text(
                    "Move Down",
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () => Navigator.of(context).pop('down'),
                ),

              ListTile(
                leading: Icon(
                  item.isArchived ? Icons.unarchive : Icons.archive,
                  color: Colors.blue,
                ),
                title: Text(
                  item.isArchived ? 'Unarchive' : 'Archive',
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () => Navigator.of(context).pop('toggleArchive'),
              ),

              ListTile(
                leading: const Icon(
                  Icons.copy,
                  color: Colors.blue,
                ),
                title: const Text(
                  'Copy',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () => Navigator.of(context).pop('copy'),
              ),

              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );
  }


  List<PopupMenuEntry<String>> _buildPopupMenuItems(
      NoteItem item, bool isArchive) {
    return [
      PopupMenuItem<String>(
        value: 'toggleTopMost',
        child: ListTile(
          leading: Icon(
            item.isTopMost ? Icons.star : Icons.star_border,
            color: item.isTopMost ? Colors.amber : Colors.grey,
          ),
          title: Text(item.isTopMost ? 'Remove from Top' : 'Add to Top'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'toggleArchive',
        child: ListTile(
          leading: Icon(
            isArchive ? Icons.unarchive : Icons.archive,
            color: Colors.blue,
          ),
          title: Text(isArchive ? 'Unarchive' : 'Archive'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'copy',
        child: ListTile(
          leading: Icon(
            Icons.copy,
            color: Colors.blue,
          ),
          title: Text("Copy"),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: ListTile(
          leading: Icon(
            Icons.delete_outline,
            color: Colors.red,
          ),
          title: Text('Delete'),
        ),
      ),
    ];
  }
}

String timeAgo(DateTime dateTime) {
  final Duration difference = DateTime.now().difference(dateTime);

  if (difference.inSeconds < 60) {
    return '${difference.inSeconds} seconds ago';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minutes ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hours ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} days ago';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()} weeks ago';
  } else if (difference.inDays < 365) {
    return '${(difference.inDays / 30).floor()} months ago';
  } else {
    return intl.DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }
}
