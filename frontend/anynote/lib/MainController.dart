import 'dart:convert';

import 'package:anynote/Extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'GlobalConfig.dart';
import 'note_api_service.dart';

typedef UpdateEditTextCallback = void Function(String id, String text);

class MainController extends GetxController {
  static String baseUrl = GlobalConfig.baseUrl;
  static String secret = GlobalConfig.secretStr;
  late final NotesApi _api;
  final RxList<NoteItem> notes = <NoteItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxString filterText = ''.obs;
  HubConnection? hubConnection;
  UpdateEditTextCallback? updateEditTextCallback;

  final RxInt fontSize = GlobalConfig.fontSize.obs;

  @override
  void onInit() {
    super.onInit();
    _api = NotesApi(baseUrl, secret);
    //initData();
  }

  void initData() async {
    print("调用了initdata");
    await fetchNotes(readLocalFirst: true);
    initSignalR();
  }

  void updateBaseUrl(String url, String newSecret) {
    baseUrl = url;
    secret = newSecret;
    _api.updateBaseUrl(url, secret);
    //initSignalR();
  }

  Future<void> initSignalR() async {
    //await hubConnection?.stop();
    hubConnection = HubConnectionBuilder()
        .withUrl('$baseUrl/notehub')
        .withAutomaticReconnect()
        .build();

    hubConnection?.on("ReceiveNoteUpdate", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final updatedNote =
            NoteItem.fromJson(arguments[0] as Map<String, dynamic>);
        updateEditTextCallback?.call(
            updatedNote.id.toString(), updatedNote.content ?? "");
        updateNoteLocally(updatedNote);
      }
    });

    hubConnection?.on("ReceiveNoteArchive", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final noteId = arguments[0] as int;
        archiveNoteLocally(noteId);
      }
    });

    hubConnection?.on("ReceiveNoteUnarchive", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final noteId = arguments[0] as int;
        unarchiveNoteLocally(noteId);
      }
    });

    hubConnection?.on("ReceiveNoteDelete", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final noteId = arguments[0] as int;
        deleteNoteLocally(noteId);
        updateEditTextCallback?.call(noteId.toString(), "_%_delete_%_");
      }
    });

    hubConnection?.on("ReceiveNewNote", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final newNote = NoteItem.fromJson(arguments[0] as Map<String, dynamic>);
        addNoteLocally(newNote);
      }
    });

    hubConnection?.on("ReceiveNoteIndicesUpdate", (arguments) {
      if (arguments != null && arguments.length == 2) {
        final ids = (arguments[0] as List<dynamic>).cast<int>();
        final indices = (arguments[1] as List<dynamic>).cast<int>();
        updateIndicesLocally(ids, indices);
      }
    });

    try {
      await hubConnection?.start();
      _api.signalrID = hubConnection?.connectionId;
      print("SignalR Connected! id=${hubConnection?.connectionId}");
    } catch (e) {
      print("Error connecting to SignalR: $e");
    }
  }

  void updateNoteLocally(NoteItem updatedNote, {int? id}) {
    final noteId = id ?? updatedNote.id;
    final index = notes.indexWhere((note) => note.id == noteId);
    if (index != -1) {
      notes[index] = updatedNote;
      notes.refresh();
    }
  }

  void archiveNoteLocally(int noteId) {
    final index = notes.indexWhere((note) => note.id == noteId);
    if (index != -1) {
      notes[index].isArchived = true;
      notes.refresh();
    }
  }

  void unarchiveNoteLocally(int noteId) {
    final index = notes.indexWhere((note) => note.id == noteId);
    if (index != -1) {
      notes[index].isArchived = false;
      notes.refresh();
    }
  }

  void deleteNoteLocally(int noteId) {
    notes.removeWhere((note) => note.id == noteId);
    saveNotesToLocal();
  }

  void addNoteLocally(NoteItem newNote) {
    final existingNoteIndex = notes.indexWhere((note) => note.id == newNote.id);
    if (existingNoteIndex != -1) {
      notes[existingNoteIndex] = newNote;
    } else {
      notes.add(newNote);
    }
  }

  void updateIndicesLocally(List<int> ids, List<int> indices) {
    for (int i = 0; i < ids.length; i++) {
      final index = notes.indexWhere((note) => note.id == ids[i]);
      if (index != -1) {
        notes[index].index = indices[i];
      }
    }
    notes.refresh();
  }

  Future<void> saveNotesToLocal() async {
    final box = Hive.box<NoteItem>('offline_notes');
    await box.clear();
    await box.addAll(notes);
  }

  Future<List<NoteItem>> loadNotesFromLocal() async {
    final box = Hive.box<NoteItem>('offline_notes');
    return box.values.toList();
  }

  Future<bool> fetchNotes({bool readLocalFirst = false}) async {
    isLoading.value = true;

    if (readLocalFirst) {
      final localNotes = await loadNotesFromLocal();
      if (localNotes.isNotEmpty) {
        notes.assignAll(localNotes);
      }
    }

    try {
      final fetchedNotes = await _api.getNotes();
      notes.assignAll(fetchedNotes);

      isLoading.value = false;

      await saveNotesToLocal();

      return true;
    } catch (e) {
      isLoading.value = false;
      if (!readLocalFirst) {
        Get.snackbar('Network Error', 'Offline mode');
      }
      print('Error fetching notes: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> login() async {
    try {
      int statusCode = await _api.login();
      if (statusCode >= 200 && statusCode < 300) {
        return {'isLoginSuccess': true, 'errorContent': null};
      } else if (statusCode == 401) {
        return {'isLoginSuccess': false, 'errorContent': 'Secret is incorrect'};
      } else {
        return {'isLoginSuccess': false, 'errorContent': 'Login Failed'};
      }
    } catch (e) {
      return {'isLoginSuccess': false, 'errorContent': e.toString()};
    }
  }

  void logout() {
    hubConnection?.stop();
    hubConnection = null;
    notes.clear();
    saveNotesToLocal();
    GlobalConfig.clear();
  }

  Future<bool> updateNote(int id, NoteItem noteItem) async {
    try {
      if (IDGenerator.isOfflineId(id)) {
        throw Exception("offline id");
      }

      final updatedNote = await _api.putNoteItem(id, noteItem);
      updateNoteLocally(updatedNote);
      await saveNotesToLocal();

      return true;
    } catch (e) {
      print('Error updating note: $e');
      return false;
    }
  }

  Future<NoteItem> addNote(NoteItem newNote) async {
    try {
      //final localId = newNote.id;
      final addedNote = await _api.addNoteItem(newNote.content ?? "");
      addNoteLocally(addedNote);
      //updateNoteLocally(addedNote, id: localId);
      return addedNote;
    } catch (e) {
      print('Error adding note: $e');
      return newNote;
    }
  }

  Future<void> archiveNote(int id) async {
    try {
      await _api.archiveItem(id);
      archiveNoteLocally(id);
    } catch (e) {
      print('Error archiving note: $e');
    }
  }

  Future<void> unarchiveNote(int id) async {
    try {
      await _api.unarchiveItem(id);
      unarchiveNoteLocally(id);
    } catch (e) {
      print('Error unarchiving note: $e');
    }
  }

  Future<void> deleteNote(int id) async {
    final confirm = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete this note?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Get.back(result: false),
              ),
              TextButton(
                child: const Text('Delete'),
                onPressed: () => Get.back(result: true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        deleteNoteLocally(id);
        await _api.deleteNoteItem(id);
      } catch (e) {
        print('Error deleting note: $e');
      }
    }
  }

  Future<void> deleteNoteWithoutPrompt(int id) async {
    try {
      deleteNoteLocally(id);
      await _api.deleteNoteItem(id);
    } catch (e) {
      print('Error deleting note without prompt: $e');
    }
  }

  Future<void> updateIndex(List<NoteItem> items) async {
    try {
      List<int> ids = items.map((item) => item.id!).toList();
      List<int> indices = [];
      for(int i = 1;i <= ids.length;i++){
        indices.add(i);
      }

      updateIndicesLocally(ids, indices);

      await _api.updateIndex(ids, indices);
    } catch (e) {
      print('Error updating note indices: $e');
    }
  }

  void updateFilter(String value) {
    final trimmedValue = value.trim().toLowerCase();
    if (filterText.value != trimmedValue) {
      filterText.value = trimmedValue;
    }
  }

  // 优化后的 filteredNotes 方法
  List<NoteItem> get filteredNotes {
    final filter = filterText.value;
    final words = filter.isNotEmpty ? filter.split(' ') : [];
    Iterable<NoteItem> res = notes;

    if (words.isNotEmpty) {
      res = res.where((item) {
        final content = (item.content ?? "").toLowerCase();
        final dateString =
            item.createTime.toIso8601String().replaceAll("-", "");
        for (final word in words) {
          if (!(content.contains(word) || dateString.contains(word))) {
            return false;
          }
        }
        return true;
      });
    }

    return sortNotes(res.toList(), false);
  }

  List<NoteItem> sortNotes(List<NoteItem> notesList, bool withIndex) {
    notesList.sort((a, b) {
      if (a.isTopMost != b.isTopMost) {
        return b.isTopMost ? 1 : -1;
      }
      if (withIndex && a.index != b.index) {
        return a.index.compareTo(b.index);
      }
      return b.createTime.compareTo(a.createTime);
    });
    return notesList;
  }

  List<NoteItem> get filteredArchivedNotes {
    return filteredNotes.where((note) => note.isArchived).toList();
  }

  List<NoteItem> get filteredUnarchivedNotes {
    var res = notes.where((note) => !note.isArchived).toList();
    sortNotes(res, true);
    return res;
  }

  Map<String, List<NoteItem>> get extractTagsWithNotes {
    final RegExp tagRegExp = RegExp(r'#([0-9a-zA-Z\u4e00-\u9fa5]+)');
    Map<String, List<NoteItem>> tagMap = {};

    for (var note in notes) {
      final matches = tagRegExp.allMatches(note.content ?? "");
      for (var match in matches) {
        String tag = match.group(1)!;
        tagMap.putIfAbsent(tag, () => []).add(note);
      }
    }

    return tagMap;
  }

  List<String> get tags {
    final RegExp tagRegExp = RegExp(r'#([0-9a-zA-Z\u4e00-\u9fa5]+)');
    Set<String> tagsSet = {};

    var sortedNotes = notes.toList();
    sortNotes(sortedNotes, true);

    for (var note in sortedNotes) {
      final matches = tagRegExp.allMatches(note.content ?? "");
      for (var match in matches) {
        String tag = match.group(1)!;
        tagsSet.add(tag);
      }
    }

    return tagsSet.toList();
  }

  List<NoteItem> get notesWithoutTag {
    final RegExp tagRegExp = RegExp(r'#([0-9a-zA-Z\u4e00-\u9fa5]+)');
    return filteredArchivedNotes.where((item) {
      return !tagRegExp.hasMatch(item.content ?? "");
    }).toList();
  }

  @override
  void onClose() {
    hubConnection?.stop();
    super.onClose();
  }

  List<MapEntry<DateTime, List<NoteItem>>> groupMemosByDate(
      List<NoteItem> memos) {
    Map<DateTime, List<NoteItem>> memoMap = {};

    for (var memo in memos) {
      // var adjustDate=memo.createTime.add(Duration(hours: -3));
      var adjustDate = memo.createTime;
      DateTime date =
          DateTime(adjustDate.year, adjustDate.month, adjustDate.day);
      if (!memoMap.containsKey(date)) {
        memoMap[date] = [];
      }
      memoMap[date]!.add(memo);
    }

    var sortedEntries = memoMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return sortedEntries;
  }
}
