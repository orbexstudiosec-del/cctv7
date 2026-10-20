package com.orbexstudios.cctvcanal7

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.PowerManager
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var wakeLock: PowerManager.WakeLock? = null

    // La misma app corre en celular y en Android TV: bootstrap.dart pregunta
    // por este canal si es una TV para abrir solo el reproductor (lib/tv/).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "viewer_app/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> result.success(isTv())
                    else -> result.notImplemented()
                }
            }
    }

    // UI_MODE_TYPE_TELEVISION es lo que reportan Android TV / Google TV;
    // FEATURE_LEANBACK cubre cajas genéricas que no siempre ponen el modo.
    private fun isTv(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }

    // wakelock_plus (usado desde Dart) solo pone FLAG_KEEP_SCREEN_ON en la
    // ventana, que en cajas Android TV genéricas no siempre alcanza para
    // frenar su protector de pantalla propio (confirmado: la imagen del
    // screensaver se seguía mostrando encima de la app). Un WakeLock real
    // de PowerManager actúa a nivel del sistema de energía, no solo de la
    // ventana, y es lo que suelen usar las apps de IPTV para esto. Se pide
    // mientras la Activity está en foreground (igual que wakelock_plus),
    // así que no hace falta tocar el lado Dart.
    @Suppress("DEPRECATION")
    override fun onResume() {
        super.onResume()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ON_AFTER_RELEASE,
            "com.orbexstudios.cctvcanal7:screen_wakelock",
        )
        wakeLock?.acquire()
    }

    override fun onPause() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onPause()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Al salir de la app (ej. para abrir WhatsApp), que el video siga
        // reproduciéndose en una ventana flotante en vez de quedar en
        // segundo plano sin pantalla. Solo en celular: en TV, salir con
        // Home debe cerrar el video, y la mayoría de cajas Android TV
        // tampoco tienen esta feature — el try/catch evita un crash ahí.
        if (isTv()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        ) {
            try {
                enterPictureInPictureMode(
                    PictureInPictureParams.Builder()
                        .setAspectRatio(Rational(16, 9))
                        .build()
                )
            } catch (_: IllegalStateException) {
                // La Activity actual no declara soporte de PiP en su manifest.
            }
        }
    }
}
