package com.orbexstudios.cctvcanal7

import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var wakeLock: PowerManager.WakeLock? = null

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
        // segundo plano sin pantalla. Solo tiene efecto en el flavor de
        // celular: el flavor de TV no declara supportsPictureInPicture en
        // su manifest (ver src/canal7tv/AndroidManifest.xml), y la
        // mayoría de cajas Android TV tampoco tienen esta feature — el
        // try/catch evita que eso cause un crash ahí.
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
