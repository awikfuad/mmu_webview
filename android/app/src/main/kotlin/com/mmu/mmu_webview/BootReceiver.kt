package com.mmu.mmu_webview

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Autostart: menjalankan MMU TV otomatis saat TV/STB dinyalakan.
 *
 * Mendengarkan:
 *  - ACTION_BOOT_COMPLETED  (boot normal)
 *  - ACTION_LOCKED_BOOT_COMPLETED (boot saat penyimpanan masih terkunci — directBootAware)
 *  - QUICKBOOT_POWERON / HTC QUICKBOOT (reboot cepat vendor box)
 *
 * Catatan Android 10+: sistem membatasi activity yang dibuka dari background receiver.
 * Untuk kiosk gunakan salah satu kuratasi, lihat README:
 *  1) Jadikan app ini default Android TV Home (aktifkan intent-filter HOME di manifest),
 *     atau
 *  2) Whitelist/batas autostart via pengaturan vendor (mis. menu "Auto Start" di box).
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val isBoot = action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == ACTION_QUICKBOOT_POWERON ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"

        if (!isBoot) return

        Log.i(TAG, "Boot diterima ($action) — autostart MMU TV")

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: return

        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TASK or
                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        )

        try {
            context.startActivity(launchIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Gagal autostart MMU TV", e)
        }
    }

    companion object {
        private const val TAG = "MMU-BootReceiver"
        private const val ACTION_QUICKBOOT_POWERON = "android.intent.action.QUICKBOOT_POWERON"
    }
}