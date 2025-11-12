package com.responsly.flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.responsly.sdk.Decision
import com.responsly.sdk.DisplayGuard
import com.responsly.sdk.LogLevel
import com.responsly.sdk.PresentationStyle
import com.responsly.sdk.QuestionAnsweredEvent
import com.responsly.sdk.Responsly
import com.responsly.sdk.ResponslyListener
import com.responsly.sdk.ResponslyOptions
import com.responsly.sdk.ShowOptions
import com.responsly.sdk.Survey
import com.responsly.sdk.SurveyCompletedEvent
import com.responsly.sdk.SurveyDismissedEvent
import com.responsly.sdk.SurveyErrorEvent
import com.responsly.sdk.SurveyNotShownEvent
import com.responsly.sdk.SurveyShownEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Forwards the Dart API of `responsly_sdk` to the Responsly Android SDK, whose sources are
 * compiled into this module (package `com.responsly.sdk`, copied by `tool/sync_native.sh`).
 *
 * One channel, both directions. Dart calls the SDK; the plugin calls Dart with the SDK's events
 * (the event's `toMap()` as arguments) and with display-guard questions. Everything here runs on
 * the main thread: Flutter delivers method calls there, and the SDK calls listeners and the
 * display guard there.
 */
class ResponslySdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ResponslyListener {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    /** Dart has a handler for our calls. Until then nothing is sent to it. */
    private var attached = false

    private val pendingGuards = HashMap<Int, Decision>()
    private var nextGuardRequestId = 1
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
        Responsly.addListener(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Responsly.removeListener(this)
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        attached = false
        // Nobody is left to answer; a guard that is still installed allows from now on.
        mainHandler.removeCallbacksAndMessages(null)
        pendingGuards.values.forEach { it.allow() }
        pendingGuards.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> attached = true
            "initialize" -> {
                val context = context
                val sdkKey = call.string("sdk_key")
                if (context == null || sdkKey == null) {
                    result.error("invalid_arguments", "initialize needs sdk_key", null)
                    return
                }
                val options = ResponslyOptions(
                    apiHost = call.string("api_host") ?: ResponslyOptions.DEFAULT_API_HOST,
                    logLevel = logLevel(call.string("log_level")),
                )
                Responsly.initialize(context, sdkKey, options)
            }
            "identify" -> {
                val userId = call.string("user_id")
                if (userId == null) {
                    result.error("invalid_arguments", "identify needs user_id", null)
                    return
                }
                Responsly.identify(userId, call.map("traits"))
            }
            "setAttributes" -> Responsly.setAttributes(call.map("traits"))
            "track" -> {
                val event = call.string("event")
                if (event == null) {
                    result.error("invalid_arguments", "track needs event", null)
                    return
                }
                Responsly.track(event, call.map("properties"))
            }
            "screen" -> {
                val name = call.string("name")
                if (name == null) {
                    result.error("invalid_arguments", "screen needs name", null)
                    return
                }
                Responsly.screen(name)
            }
            "showSurvey" -> {
                val surveyId = call.string("survey_id")
                if (surveyId == null) {
                    result.error("invalid_arguments", "showSurvey needs survey_id", null)
                    return
                }
                val options = ShowOptions(
                    force = call.argument<Any?>("force") == true,
                    hiddenFields = call.stringMap("hidden_fields"),
                    locale = call.string("locale"),
                    presentation = call.string("presentation")?.let(PresentationStyle::fromValue),
                )
                Responsly.showSurvey(surveyId, options)
            }
            "closeSurvey" -> Responsly.closeSurvey()
            "pause" -> Responsly.pause()
            "resume" -> Responsly.resume()
            "setLocale" -> Responsly.setLocale(call.string("locale"))
            "setHiddenFields" -> Responsly.setHiddenFields(call.stringMap("fields"))
            "setTrackingEnabled" -> Responsly.setTrackingEnabled(call.argument<Any?>("enabled") != false)
            "reset" -> Responsly.reset()
            "setDisplayGuard" ->
                if (call.argument<Any?>("enabled") == true) {
                    Responsly.setDisplayGuard(DisplayGuard { survey, decision -> askDart(survey, decision) })
                } else {
                    Responsly.setDisplayGuard(null)
                }
            "resolveDisplayGuard" -> {
                val requestId = (call.argument<Any?>("request_id") as? Number)?.toInt()
                val decision = if (requestId == null) null else pendingGuards.remove(requestId)
                if (call.argument<Any?>("allow") == false) decision?.veto() else decision?.allow()
            }
            else -> {
                result.notImplemented()
                return
            }
        }
        result.success(null)
    }

    // ResponslyListener: every event goes to Dart as the SDK describes it.

    override fun onSurveyShown(event: SurveyShownEvent) = send("surveyShown", event.toMap())

    override fun onSurveyNotShown(event: SurveyNotShownEvent) = send("surveyNotShown", event.toMap())

    override fun onQuestionAnswered(event: QuestionAnsweredEvent) = send("questionAnswered", event.toMap())

    override fun onSurveyCompleted(event: SurveyCompletedEvent) = send("surveyCompleted", event.toMap())

    override fun onSurveyDismissed(event: SurveyDismissedEvent) = send("surveyDismissed", event.toMap())

    override fun onSurveyError(event: SurveyErrorEvent) = send("surveyError", event.toMap())

    /**
     * The SDK's display guard: asks Dart with a request id and keeps the decision until Dart
     * answers with `resolveDisplayGuard`. The SDK itself allows after 2 seconds without an answer.
     */
    private fun askDart(survey: Survey, decision: Decision) {
        if (channel == null || !attached) {
            decision.allow()
            return
        }
        val requestId = nextGuardRequestId++
        pendingGuards[requestId] = decision
        send("displayGuard", mapOf("request_id" to requestId, "survey" to survey.toMap()))
        // An answer this late is ignored by the SDK; only forget the request.
        mainHandler.postDelayed({ pendingGuards.remove(requestId) }, PENDING_GUARD_LIFETIME_MILLIS)
    }

    private fun send(method: String, arguments: Map<String, Any?>) {
        if (attached) channel?.invokeMethod(method, arguments)
    }

    private fun logLevel(name: String?): LogLevel = when (name) {
        "none" -> LogLevel.NONE
        "info" -> LogLevel.INFO
        "debug" -> LogLevel.DEBUG
        else -> LogLevel.ERROR
    }

    private companion object {
        const val CHANNEL = "responsly_sdk"
        const val PENDING_GUARD_LIFETIME_MILLIS = 10_000L
    }
}

private fun MethodCall.string(key: String): String? = argument<Any?>(key) as? String

/** A map argument with its string keys; values stay as the channel decoded them. */
private fun MethodCall.map(key: String): Map<String, Any?> {
    val raw = argument<Any?>(key) as? Map<*, *> ?: return emptyMap()
    val result = LinkedHashMap<String, Any?>(raw.size)
    for ((name, value) in raw) if (name is String) result[name] = value
    return result
}

private fun MethodCall.stringMap(key: String): Map<String, String> {
    val raw = argument<Any?>(key) as? Map<*, *> ?: return emptyMap<String, String>()
    val result = LinkedHashMap<String, String>(raw.size)
    for ((name, value) in raw) if (name is String && value is String) result[name] = value
    return result
}
