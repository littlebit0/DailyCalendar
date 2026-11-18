package com.littlebit0.dailycalendar

import android.app.backup.BackupAgent
import android.app.backup.BackupDataInput
import android.app.backup.BackupDataOutput
import android.content.Context
import android.os.ParcelFileDescriptor

/**
 * Auto Backup still decides what is copied (`daily_backup_rules`,
 * `daily_data_extraction_rules`); `fullBackupOnly` keeps it from switching to
 * key/value backup. #968: the PIN lives in secure storage, which those rules
 * exclude because its Keystore key never leaves the device. The app lock
 * settings share FlutterSharedPreferences with every other setting, so they
 * are removed here once a restore has written that file.
 */
class DailyBackupAgent : BackupAgent() {
    override fun onBackup(
        oldState: ParcelFileDescriptor?,
        data: BackupDataOutput?,
        newState: ParcelFileDescriptor?,
    ) = Unit

    override fun onRestore(data: BackupDataInput?, appVersionCode: Int, newState: ParcelFileDescriptor?) = Unit

    override fun onRestoreFinished() {
        removeRestoredAppLockSettings(this)
    }

    companion object {
        /** `SettingsRepository` lock keys as the shared_preferences plugin stores them. */
        internal val APP_LOCK_KEYS = listOf(
            "flutter.appLockConfiguration.v1",
            "flutter.appLockEnabled",
            "flutter.appLockBiometricsEnabled",
            "flutter.appLockMethod",
        )

        internal fun removeRestoredAppLockSettings(context: Context): Boolean {
            val editor = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            APP_LOCK_KEYS.forEach(editor::remove)
            return editor.commit()
        }
    }
}
