package com.littlebit0.dailycalendar

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import com.baseflow.geolocator.GeolocatorPlugin
import com.baseflow.geolocator.errors.ErrorCodes
import com.baseflow.geolocator.permission.LocationPermission
import com.baseflow.geolocator.permission.PermissionManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** #396: the static PermissionManager must not keep a finished request's Activity or callbacks. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class GeolocatorPermissionReleaseTest {
    private val manager = PermissionManager.getInstance()
    private val results = mutableListOf<LocationPermission>()
    private val errors = mutableListOf<ErrorCodes>()

    private fun field(name: String): Any? =
        PermissionManager::class.java.getDeclaredField(name).apply { isAccessible = true }.get(manager)

    private fun assertReleased() {
        assertNull(field("activity"))
        assertNull(field("resultCallback"))
        assertNull(field("errorCallback"))
    }

    private fun activity(): Activity = Robolectric.buildActivity(Activity::class.java).create().get()

    private fun request(activity: Activity) =
        manager.requestPermission(activity, { results.add(it) }, { errors.add(it) })

    private fun respond(result: Int) = manager.onRequestPermissionsResult(
        109, arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), intArrayOf(result))

    private fun binding(activity: Activity): ActivityPluginBinding =
        Proxy.newProxyInstance(javaClass.classLoader, arrayOf(ActivityPluginBinding::class.java)) { _, method, _ ->
            if (method.name == "getActivity") activity else null
        } as ActivityPluginBinding

    @Before fun reset() {
        for (name in listOf("activity", "resultCallback", "errorCallback")) {
            PermissionManager::class.java.getDeclaredField(name).apply { isAccessible = true }.set(manager, null)
        }
    }

    @Test fun grantedAndDeniedResultsReleaseTheRequest() {
        request(activity())
        assertTrue(respond(PackageManager.PERMISSION_GRANTED))
        assertEquals(listOf(LocationPermission.always), results)
        assertReleased()

        request(activity())
        assertTrue(respond(PackageManager.PERMISSION_DENIED))
        assertEquals(LocationPermission.deniedForever, results.last())
        assertTrue(errors.isEmpty())
        assertReleased()
    }

    @Test fun aRequestStartedByTheCallbackIsKept() {
        val next = activity()
        val nextResults = mutableListOf<LocationPermission>()
        manager.requestPermission(activity(), {
            manager.requestPermission(next, { nextResults.add(it) }, { errors.add(it) })
        }, { errors.add(it) })
        respond(PackageManager.PERMISSION_GRANTED)
        assertSame(next, field("activity"))
        respond(PackageManager.PERMISSION_GRANTED)
        assertEquals(listOf(LocationPermission.always), nextResults)
        assertReleased()
    }

    @Test fun finalActivityDetachFailsAndReleasesOnlyItsOwnRequest() {
        val owner = activity()
        request(owner)
        assertFalse(manager.onActivityDetached(activity(), false))
        assertSame(owner, field("activity"))

        assertFalse(manager.onActivityDetached(owner, false))
        assertEquals(listOf(ErrorCodes.activityMissing), errors)
        assertReleased()
    }

    @Test fun configChangeMovesTheRequestToTheRecreatedActivity() {
        val plugin = GeolocatorPlugin()
        val old = activity()
        plugin.onAttachedToActivity(binding(old))
        request(old)
        plugin.onDetachedFromActivityForConfigChanges()
        assertNull(field("activity"))
        assertNotNull(field("resultCallback"))

        val recreated = activity()
        plugin.onReattachedToActivityForConfigChanges(binding(recreated))
        assertSame(recreated, field("activity"))
        respond(PackageManager.PERMISSION_GRANTED)
        assertEquals(listOf(LocationPermission.always), results)
        assertTrue(errors.isEmpty())
        assertReleased()
    }

    @Test fun engineDetachFailsARequestWaitingForItsActivity() {
        val plugin = GeolocatorPlugin()
        val old = activity()
        plugin.onAttachedToActivity(binding(old))
        request(old)
        plugin.onDetachedFromActivityForConfigChanges()
        // A plugin of another engine does not own the waiting request.
        GeolocatorPlugin::class.java.getDeclaredMethod("dispose").apply { isAccessible = true }.invoke(GeolocatorPlugin())
        assertNotNull(field("resultCallback"))

        GeolocatorPlugin::class.java.getDeclaredMethod("dispose").apply { isAccessible = true }.invoke(plugin)
        assertEquals(listOf(ErrorCodes.activityMissing), errors)
        assertReleased()
    }
}
