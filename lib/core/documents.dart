// PDF pour le médecin : enregistrés dans l'appli (liste « Documents déjà
// créés ») et copiés dans Téléchargements (Android 10 et plus). L'ouverture et
// l'envoi par e-mail passent par Android ; en cas d'échec, l'écran se rabat sur
// le partage classique.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class SavedDoc {
  final File file;
  final String? downloadsUri; // content://... dans Téléchargements, si copié
  final DateTime created;
  const SavedDoc(this.file, this.downloadsUri, this.created);

  String get name => file.uri.pathSegments.last;

  /// « Suivi du 24 octobre au 22 novembre 2026 », tiré du nom du fichier.
  String get title {
    final m = RegExp(r'(\d{4}-\d{2}-\d{2})-au-(\d{4}-\d{2}-\d{2})').firstMatch(name);
    if (m == null) return name;
    final a = DateTime.parse(m.group(1)!);
    final b = DateTime.parse(m.group(2)!);
    final end = DateFormat('d MMMM yyyy', 'fr_FR').format(b);
    final start = DateFormat(a.year == b.year ? 'd MMMM' : 'd MMMM yyyy', 'fr_FR').format(a);
    return 'Suivi du $start au $end';
  }

  String get sizeLabel {
    final kb = (file.lengthSync() / 1024).ceil();
    return kb < 1024 ? '$kb Ko' : '${(kb / 1024).toStringAsFixed(1)} Mo';
  }
}

class Documents {
  static const _channel = MethodChannel('fr.babas50.tictac/documents');

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/exports');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<File> _index() async => File('${(await _dir()).path}/index.json');

  static Future<Map<String, dynamic>> _readIndex() async {
    try {
      final f = await _index();
      if (!f.existsSync()) return {};
      return (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// Enregistre le PDF. Renvoie le document, copié dans Téléchargements quand
  /// Android le permet ([SavedDoc.downloadsUri] non nul).
  static Future<SavedDoc> save(List<int> bytes, String name) async {
    final dir = await _dir();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    String? uri;
    try {
      uri = await _channel.invokeMethod<String>('saveToDownloads', {'path': file.path, 'name': name});
    } catch (_) {
      uri = null; // Android 9 et moins, ou tests : le fichier reste dans l'appli.
    }
    final idx = await _readIndex();
    if (uri != null) idx[name] = uri;
    await (await _index()).writeAsString(jsonEncode(idx));
    return SavedDoc(file, uri, DateTime.now());
  }

  /// Documents déjà créés, du plus récent au plus ancien.
  static Future<List<SavedDoc>> list() async {
    final dir = await _dir();
    final idx = await _readIndex();
    final docs = [
      for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')))
        SavedDoc(f, idx[f.uri.pathSegments.last] as String?, f.lastModifiedSync()),
    ]..sort((a, b) => b.created.compareTo(a.created));
    return docs;
  }

  static Future<void> delete(SavedDoc d) async {
    if (d.file.existsSync()) d.file.deleteSync();
  }

  /// Ouvre le PDF dans le lecteur du téléphone. Faux si impossible.
  static Future<bool> open(SavedDoc d) async {
    if (d.downloadsUri == null) return false;
    try {
      return await _channel.invokeMethod<bool>('open', {'uri': d.downloadsUri}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ouvre l'appli de messagerie avec le PDF joint. Faux si impossible.
  static Future<bool> email(SavedDoc d, {String? to, required String subject, required String body}) async {
    if (d.downloadsUri == null) return false;
    try {
      return await _channel.invokeMethod<bool>('email', {
            'uri': d.downloadsUri,
            'to': (to == null || to.trim().isEmpty) ? null : to.trim(),
            'subject': subject,
            'body': body,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
