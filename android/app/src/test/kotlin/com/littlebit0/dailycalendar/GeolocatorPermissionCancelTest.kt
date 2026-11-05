package com.littlebit0.dailycalendar

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import com.baseflow.geolocator.errors.ErrorCodes
import com.baseflow.geolocator.permission.LocationPermission
import com.baseflow.geolocator.permission.PermissionManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Issue #395: an interrupted permission request must still answer the Flutter call. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class GeolocatorPermissionCancelTest {
    private val manager = PermissionManager.getInstance()
    private val results = mutableListOf<LocationPermission>()
    private val errors = mutableListOf<ErrorCodes>()

    private fun request(activity: Activity) =
        manager.requestPermission(activity, { results += it }, { errors += it })

    @Test fun emptyResultCompletesOnceAsPlainDenial() {
        request(Robolectric.buildActivity(Activity::class.java).setup().get())

        assertTrue(manager.onRequestPermissionsResult(109, emptyArray(), IntArray(0)))
        // A late duplicate or a normal result for the finished request is not answered again.
        assertFalse(manager.onRequestPermissionsResult(109, emptyArray(), IntArray(0)))
        manager.onRequestPermissionsResult(
            109,
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            intArrayOf(PackageManager.PERMISSION_GRANTED),
        )

        // denied, not deniedForever: the cancellation must not block a later prompt.
        assertEquals(listOf(LocationPermission.denied), results)
        assertTrue(errors.isEmpty())
    }

    @Test fun otherRequestCodeIsIgnoredAndRequestStillCompletes() {
        request(Robolectric.buildActivity(Activity::class.java).setup().get())

        assertFalse(manager.onRequestPermissionsResult(42, emptyArray(), IntArray(0)))
        assertTrue(results.isEmpty())

        assertTrue(manager.onRequestPermissionsResult(109, emptyArray(), IntArray(0)))
        assertEquals(listOf(LocationPermission.denied), results)
    }

    @Test fun newRequestAfterCancellationGetsItsOwnResult() {
        request(Robolectric.buildActivity(Activity::class.java).setup().get())
        manager.onRequestPermissionsResult(109, emptyArray(), IntArray(0))

        val second = mutableListOf<LocationPermission>()
        manager.requestPermission(
            Robolectric.buildActivity(Activity::class.java).setup().get(),
            { second += it },
            { errors += it },
        )
        assertTrue(
            manager.onRequestPermissionsResult(
                109,
                arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
                intArrayOf(PackageManager.PERMISSION_GRANTED),
            ),
        )

        assertEquals(listOf(LocationPermission.denied), results)
        assertEquals(listOf(LocationPermission.whileInUse), second)
        assertTrue(errors.isEmpty())
    }
}
