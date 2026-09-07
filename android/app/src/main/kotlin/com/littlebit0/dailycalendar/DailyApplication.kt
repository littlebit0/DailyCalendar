package com.littlebit0.dailycalendar

import android.app.Application
import android.content.res.Configuration

class DailyApplication : Application() {
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        DailyWidgetUpdater.refreshAll(this)
    }
}
