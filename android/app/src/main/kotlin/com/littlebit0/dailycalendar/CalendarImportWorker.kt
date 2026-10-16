package com.littlebit0.dailycalendar

import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.OperationCanceledException
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** One bounded import at a time. Permission UI remains on the Activity thread. */
internal class CalendarImportWorker(
    private val executor: ExecutorService = Executors.newSingleThreadExecutor(),
    private val main: Handler = Handler(Looper.getMainLooper()),
) {
    private class Request(val result: MethodChannel.Result, val signal: CancellationSignal)
    private var active: Request? = null
    private var closed = false

    fun submit(result: MethodChannel.Result, query: (CancellationSignal) -> Any?) {
        if (closed || active != null) {
            result.error("calendar_import_busy", "캘린더 가져오기를 시작할 수 없습니다.", null)
            return
        }
        val request = Request(result, CancellationSignal())
        active = request
        executor.execute {
            try {
                request.signal.throwIfCanceled()
                val value = query(request.signal)
                request.signal.throwIfCanceled()
                main.post { finish(request) { result.success(value) } }
            } catch (error: Exception) {
                val code = when (error) {
                    is SecurityException -> "calendar_permission_denied"
                    is OperationCanceledException, is InterruptedException -> "calendar_import_cancelled"
                    else -> "calendar_import_failed"
                }
                main.post {
                    finish(request) { result.error(code, "캘린더를 가져오지 못했습니다. 다시 시도해 주세요.", null) }
                }
            }
        }
    }

    private fun finish(request: Request, reply: () -> Unit) {
        if (active !== request) return
        active = null
        reply()
    }

    fun close() {
        if (closed) return
        closed = true
        val request = active
        active = null
        request?.signal?.cancel()
        request?.result?.error("calendar_import_cancelled", "캘린더 가져오기가 취소됐습니다.", null)
        executor.shutdownNow()
    }
}
