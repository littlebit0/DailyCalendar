package com.littlebit0.dailycalendar

import android.content.Context
import android.content.pm.ApplicationInfo
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.xmlpull.v1.XmlPullParser

/** #968: secure storage and app lock settings must not come back from a backup. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DailyBackupAgentTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Test
    fun restoreRemovesOnlyAppLockSettings() {
        val preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val editor = preferences.edit().putString("flutter.themeMode", "dark")
        DailyBackupAgent.APP_LOCK_KEYS.forEach { editor.putString(it, "restored") }
        editor.commit()

        assertTrue(DailyBackupAgent.removeRestoredAppLockSettings(context))

        DailyBackupAgent.APP_LOCK_KEYS.forEach { assertFalse(it, preferences.contains(it)) }
        assertEquals("dark", preferences.getString("flutter.themeMode", null))
    }

    @Test
    fun manifestUsesTheAgentWithAutoBackup() {
        val info = context.packageManager.getApplicationInfo(context.packageName, 0)
        assertEquals(DailyBackupAgent::class.java.name, info.backupAgentName)
        assertTrue(info.flags and ApplicationInfo.FLAG_FULL_BACKUP_ONLY != 0)
    }

    @Test
    fun backupRulesExcludeDefaultSecureStorage() {
        val required = setOf(
            "daily_lms_credentials.xml",
            "FlutterSecureKeyStorage:daily_lms_credentials.xml",
            "FlutterSecureStorage.xml",
            "FlutterSecureKeyStorage.xml",
        )
        assertEquals(listOf(required), excludedPaths(R.xml.daily_backup_rules))
        // cloud-backup and device-transfer each list the same files.
        assertEquals(listOf(required, required), excludedPaths(R.xml.daily_data_extraction_rules))
    }

    /** Excluded sharedpref paths per rule section. */
    private fun excludedPaths(resource: Int): List<Set<String>> {
        val parser = context.resources.getXml(resource)
        val sections = mutableListOf<MutableSet<String>>()
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType != XmlPullParser.START_TAG) continue
            when (parser.name) {
                "full-backup-content", "cloud-backup", "device-transfer" -> sections += mutableSetOf<String>()
                "exclude" -> {
                    assertEquals("sharedpref", parser.getAttributeValue(null, "domain"))
                    sections.last() += parser.getAttributeValue(null, "path")
                }
            }
        }
        return sections
    }
}
