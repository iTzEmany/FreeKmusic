package com.codecore.player

import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import org.schabi.newpipe.extractor.stream.DeliveryMethod
import org.schabi.newpipe.extractor.stream.StreamInfo
import java.net.HttpURLConnection
import java.net.URL

private const val UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0"

/** Minimal NewPipe downloader over HttpURLConnection (no cookies, no proxy). */
private object PlainDownloader : Downloader() {
    override fun execute(request: Request): Response {
        val c = URL(request.url()).openConnection() as HttpURLConnection
        c.requestMethod = request.httpMethod()
        c.connectTimeout = 15000
        c.readTimeout = 20000
        c.setRequestProperty("User-Agent", UA)
        request.headers().forEach { (k, v) -> c.setRequestProperty(k, v.joinToString(", ")) }
        request.dataToSend()?.let {
            c.doOutput = true
            c.outputStream.use { o -> o.write(it) }
        }
        val code = c.responseCode
        if (code == 429) throw ReCaptchaException("rate limited", request.url())
        val body = (if (code >= 400) c.errorStream else c.inputStream)?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
        val headers = c.headerFields.filterKeys { it != null }
        return Response(code, c.responseMessage, headers, body, c.url.toString())
    }
}

object NewPipeUrl {
    private val initMs: Long by lazy {
        val t = System.currentTimeMillis()
        NewPipe.init(PlainDownloader)
        System.currentTimeMillis() - t
    }

    /** Best progressive audio stream of a video: m4a/AAC first, then the highest bitrate, under the cap of [capKbps] kbit/s when one stream fits. */
    fun streamUrl(id: String, capKbps: Int? = null): Map<String, Any?> {
        val t = System.currentTimeMillis()
        val init = initMs
        val info = StreamInfo.getInfo(ServiceList.YouTube, "https://www.youtube.com/watch?v=$id")
        val all = info.audioStreams
            .filter { it.deliveryMethod == DeliveryMethod.PROGRESSIVE_HTTP && it.content.isNotEmpty() }
        val cap = capKbps ?: Int.MAX_VALUE
        // Unknown bitrate (-1) passes; with nothing under the cap the lowest one is taken.
        val fit = all.filter { it.averageBitrate <= cap }
        val best = (if (fit.isNotEmpty() || cap == Int.MAX_VALUE) fit else listOf(all.minByOrNull { it.averageBitrate }).filterNotNull())
            .sortedWith(compareByDescending<org.schabi.newpipe.extractor.stream.AudioStream> {
                it.format?.suffix == "m4a"
            }.thenByDescending { it.averageBitrate })
            .firstOrNull() ?: throw IllegalStateException("no progressive audio stream")
        val ms = System.currentTimeMillis() - t
        android.util.Log.i("codecore", "newpipe init=${init}ms info=${ms}ms")
        return mapOf(
            "url" to best.content,
            "headers" to mapOf("User-Agent" to UA),
            "format" to best.format?.suffix,
            "bitrate" to best.averageBitrate,
            "ms" to ms,
        )
    }
}
