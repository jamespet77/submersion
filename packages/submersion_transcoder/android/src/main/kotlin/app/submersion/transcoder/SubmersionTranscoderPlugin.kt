package app.submersion.transcoder

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val METHODS = "submersion_transcoder/methods"
private const val PROGRESS = "submersion_transcoder/progress"

/**
 * Android side of the submersion_transcoder plugin. Implements the same
 * method + event channel contract as the darwin (AVFoundation) plugin so the
 * shared Dart [ChannelTranscodeEngine] talks to either without change.
 */
class SubmersionTranscoderPlugin :
    FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methods: MethodChannel
    private lateinit var progress: EventChannel
    private lateinit var context: Context
    private var progressSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, METHODS)
        methods.setMethodCallHandler(this)
        progress = EventChannel(binding.binaryMessenger, PROGRESS)
        progress.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        progress.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        progressSink = events
    }

    override fun onCancel(arguments: Any?) {
        progressSink = null
    }
}
