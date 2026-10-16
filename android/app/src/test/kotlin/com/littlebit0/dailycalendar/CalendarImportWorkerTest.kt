package com.littlebit0.dailycalendar

import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class CalendarImportWorkerTest {
    private class Reply : MethodChannel.Result {
        var calls = 0
        var value: Any? = null
        var code: String? = null
        override fun success(result: Any?) { calls++; value = result }
        override fun error(errorCode: String, message: String?, details: Any?) { calls++; code = errorCode }
        override fun notImplemented() { calls++ }
    }
    private fun awaitReply(reply: Reply) {
        val end = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (reply.calls == 0 && System.nanoTime() < end) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(5)
        }
        assertEquals(1, reply.calls)
    }
    @Test fun queryRunsOffMainAndPreservesLargeResult() {
        val worker = CalendarImportWorker()
        try {
            val reply = Reply()
            worker.submit(reply) {
                assertNotEquals(Looper.getMainLooper().thread, Thread.currentThread())
                (0 until 10000).map { mapOf("id" to it.toString()) }
            }
            awaitReply(reply)
            assertEquals(10000, (reply.value as List<*>).size)
            assertNull(reply.code)
        } finally { worker.close() }
    }
    @Test fun destructionCancelsInFlightAndRepliesOnce() {
        val worker = CalendarImportWorker()
        val started = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val reply = Reply()
        worker.submit(reply) { signal ->
            started.countDown()
            try {
                while (!signal.isCanceled) Thread.sleep(5)
                signal.throwIfCanceled()
            } finally { finished.countDown() }
        }
        assertTrue(started.await(5, TimeUnit.SECONDS))
        val busy = Reply()
        worker.submit(busy) { fail("must not enqueue another import") }
        assertEquals("calendar_import_busy", busy.code)
        worker.close()
        assertTrue(finished.await(5, TimeUnit.SECONDS))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, reply.calls)
        assertEquals("calendar_import_cancelled", reply.code)
    }
    @Test fun revokedPermissionDoesNotPoisonNextRequest() {
        val worker = CalendarImportWorker()
        try {
            val failed = Reply()
            worker.submit(failed) { throw SecurityException("fixture") }
            awaitReply(failed)
            assertEquals("calendar_permission_denied", failed.code)
            val retry = Reply()
            worker.submit(retry) { listOf("ok") }
            awaitReply(retry)
            assertEquals(listOf("ok"), retry.value)
        } finally { worker.close() }
    }
}
