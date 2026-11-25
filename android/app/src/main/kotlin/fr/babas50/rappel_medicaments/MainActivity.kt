package fr.babas50.rappel_medicaments

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Canal « documents » : copie du PDF médecin dans Téléchargements (Android 10
 * et plus, sans autorisation), puis ouverture ou envoi par e-mail de ce
 * fichier.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fr.babas50.tictac/documents")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "saveToDownloads" -> {
                            val path = call.argument<String>("path")
                            val name = call.argument<String>("name")
                            if (path == null || name == null) {
                                result.error("args", "Chemin ou nom manquant", null)
                            } else {
                                result.success(saveToDownloads(File(path), name))
                            }
                        }
                        "open" -> {
                            val uri = Uri.parse(call.argument<String>("uri") ?: "")
                            val view = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/pdf")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(view, "Ouvrir le PDF"))
                            result.success(true)
                        }
                        "email" -> {
                            val uri = Uri.parse(call.argument<String>("uri") ?: "")
                            val to = call.argument<String>("to")
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "application/pdf"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                if (to != null) putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
                                putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("subject") ?: "")
                                putExtra(Intent.EXTRA_TEXT, call.argument<String>("body") ?: "")
                                clipData = ClipData.newRawUri("", uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                // Ne propose que les applis de messagerie.
                                selector = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
                            }
                            startActivity(send)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                } catch (e: Exception) {
                    result.error("documents", e.message, null)
                }
            }
    }

    /** Copie [file] dans Téléchargements et renvoie son adresse content://, ou null avant Android 10. */
    private fun saveToDownloads(file: File, name: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
        resolver.openOutputStream(uri)?.use { out ->
            file.inputStream().use { input -> input.copyTo(out) }
        }
        val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
        resolver.update(uri, done, null, null)
        return uri.toString()
    }
}
