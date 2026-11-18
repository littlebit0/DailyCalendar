package com.littlebit0.dailycalendar

import org.junit.Assert.assertEquals
import org.junit.Test

class DailyAlarmPermissionStepTest {
    private fun steps(
        sdk: Int = 34,
        granted: Boolean = false,
        blocked: Boolean = false,
        openSettings: Boolean = true,
        allowedAfterSettings: Boolean = false,
    ): List<AlarmPermissionStep> {
        val attempted = mutableSetOf<String>()
        val seen = mutableListOf<AlarmPermissionStep>()
        var allowed = false
        while (true) {
            val step = nextAlarmPermissionStep(sdk, allowed, granted, blocked, true, true, openSettings, attempted)
            seen += step
            if (step == AlarmPermissionStep.AUTHORIZED || step == AlarmPermissionStep.DENIED) return seen
            if (step == AlarmPermissionStep.NOTIFICATION_SETTINGS) allowed = allowedAfterSettings
        }
    }

    @Test fun permanentlyRefusedPermissionOpensSettingsAfterTheSilentRequest() = assertEquals(
        listOf(AlarmPermissionStep.RUNTIME_NOTIFICATION, AlarmPermissionStep.NOTIFICATION_SETTINGS, AlarmPermissionStep.DENIED),
        steps(blocked = true),
    )

    @Test fun mutedAppOrChannelOpensSettingsWithoutARuntimeRequest() = assertEquals(
        listOf(AlarmPermissionStep.NOTIFICATION_SETTINGS, AlarmPermissionStep.DENIED),
        steps(granted = true),
    )

    @Test fun allowingInSettingsFinishesTheSameRequestAsAuthorized() = assertEquals(
        listOf(AlarmPermissionStep.NOTIFICATION_SETTINGS, AlarmPermissionStep.AUTHORIZED),
        steps(granted = true, allowedAfterSettings = true),
    )

    @Test fun startupRequestNeverOpensNotificationSettings() {
        assertEquals(listOf(AlarmPermissionStep.RUNTIME_NOTIFICATION, AlarmPermissionStep.DENIED), steps(blocked = true, openSettings = false))
        assertEquals(listOf(AlarmPermissionStep.DENIED), steps(granted = true, openSettings = false))
    }

    @Test fun refusalInTheDialogDoesNotOpenSettings() = assertEquals(
        listOf(AlarmPermissionStep.RUNTIME_NOTIFICATION, AlarmPermissionStep.DENIED),
        steps(),
    )

    @Test fun beforeApi33SettingsOpenOnceAsBefore() = assertEquals(
        listOf(AlarmPermissionStep.NOTIFICATION_SETTINGS, AlarmPermissionStep.DENIED),
        steps(sdk = 32, openSettings = false),
    )

    @Test fun exactAlarmAndFullScreenScreensEachOpenOnce() {
        val attempted = mutableSetOf<String>()
        fun next(exact: Boolean, fullScreen: Boolean) = nextAlarmPermissionStep(34, true, true, false, exact, fullScreen, false, attempted)
        assertEquals(AlarmPermissionStep.EXACT_ALARM, next(false, false))
        assertEquals(AlarmPermissionStep.DENIED, next(false, false))
        assertEquals(AlarmPermissionStep.FULL_SCREEN, next(true, false))
        assertEquals(AlarmPermissionStep.DENIED, next(true, false))
        assertEquals(AlarmPermissionStep.AUTHORIZED, next(true, true))
    }
}
