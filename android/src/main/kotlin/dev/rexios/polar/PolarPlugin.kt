package dev.rexios.polar

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.Lifecycle.Event
import androidx.lifecycle.LifecycleEventObserver
import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonPrimitive
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import com.polar.androidcommunications.api.ble.model.DisInfo
import com.polar.androidcommunications.api.ble.model.gatt.client.ChargeState
import com.polar.androidcommunications.api.ble.model.gatt.client.PowerSourcesState
import com.polar.sdk.api.PolarBleApi
import com.polar.sdk.api.PolarBleApi.PolarBleSdkFeature
import com.polar.sdk.api.PolarBleApi.PolarDeviceDataType
import com.polar.sdk.api.PolarBleApiCallbackProvider
import com.polar.sdk.api.PolarBleApiDefaultImpl
import com.polar.sdk.api.PolarH10OfflineExerciseApi.RecordingInterval
import com.polar.sdk.api.PolarH10OfflineExerciseApi.SampleType
import com.polar.sdk.api.model.LedConfig
import com.polar.sdk.api.model.PolarDeviceInfo
import com.polar.sdk.api.model.PolarExerciseEntry
import com.polar.sdk.api.model.PolarFirstTimeUseConfig
import com.polar.sdk.api.model.PolarHealthThermometerData
import com.polar.sdk.api.model.PolarHrData
import com.polar.sdk.api.model.PolarSensorSetting
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.lang.reflect.Type
import java.util.Date
import java.util.UUID

fun Any?.discard() = Unit

object DateSerializer : JsonDeserializer<Date>, JsonSerializer<Date> {
    override fun deserialize(
        json: JsonElement?,
        typeOfT: Type?,
        context: JsonDeserializationContext?,
    ): Date = Date(json?.asJsonPrimitive?.asLong ?: 0)

    override fun serialize(
        src: Date?,
        typeOfSrc: Type?,
        context: JsonSerializationContext?,
    ): JsonElement = JsonPrimitive(src?.time)
}

private fun runOnUiThread(runnable: () -> Unit) {
    Handler(Looper.getMainLooper()).post { runnable() }
}

private val gson = GsonBuilder()
    .registerTypeAdapter(Date::class.java, DateSerializer)
    .registerTypeAdapter(java.time.ZonedDateTime::class.java, JsonSerializer<java.time.ZonedDateTime> { src, _, _ -> JsonPrimitive(java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(src)) })
    .registerTypeAdapter(java.time.LocalDate::class.java, JsonSerializer<java.time.LocalDate> { src, _, _ -> JsonPrimitive(src.toString()) })
    .create()

private var wrapperInternal: PolarWrapper? = null
private val wrapper: PolarWrapper
    get() = wrapperInternal!!

/** PolarPlugin */
class PolarPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {
    // Binary messenger for dynamic EventChannel registration
    private lateinit var messenger: BinaryMessenger

    // Method channel
    private lateinit var methodChannel: MethodChannel

    // Event channel
    private lateinit var eventChannel: EventChannel

    // Search channel
    private lateinit var searchChannel: EventChannel

    // Context
    private lateinit var context: Context

    // Streaming channels
    private val streamingChannels = mutableMapOf<String, StreamingChannel>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        messenger = flutterPluginBinding.binaryMessenger

        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "polar/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "polar/events")
        eventChannel.setStreamHandler(this)

        searchChannel = EventChannel(flutterPluginBinding.binaryMessenger, "polar/search")
        searchChannel.setStreamHandler(searchHandler)

        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        searchChannel.setStreamHandler(null)
        streamingChannels.values.forEach { it.dispose() }
        shutDown()
    }

    private fun initApi() {
        if (wrapperInternal == null) {
            wrapperInternal = PolarWrapper(context)
        }
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        initApi()

        when (call.method) {
            "connectToDevice" -> {
                wrapper.api.connectToDevice(call.arguments as String)
                result.success(null)
            }

            "disconnectFromDevice" -> {
                wrapper.api.disconnectFromDevice(call.arguments as String)
                result.success(null)
            }

            "getAvailableOnlineStreamDataTypes" -> {
                getAvailableOnlineStreamDataTypes(call, result)
            }

            "getAvailableHrServiceDataTypes" -> {
                getAvailableHrServiceDataTypes(call, result)
            }

            "requestStreamSettings" -> {
                requestStreamSettings(call, result)
            }

            "createStreamingChannel" -> {
                createStreamingChannel(call, result)
            }

            "startRecording" -> {
                startRecording(call, result)
            }

            "stopRecording" -> {
                stopRecording(call, result)
            }

            "requestRecordingStatus" -> {
                requestRecordingStatus(call, result)
            }

            "listExercises" -> {
                listExercises(call, result)
            }

            "fetchExercise" -> {
                fetchExercise(call, result)
            }

            "removeExercise" -> {
                removeExercise(call, result)
            }

            "setLedConfig" -> {
                setLedConfig(call, result)
            }

            "doFactoryReset" -> {
                doFactoryReset(call, result)
            }

            "enableSdkMode" -> {
                enableSdkMode(call, result)
            }

            "disableSdkMode" -> {
                disableSdkMode(call, result)
            }

            "isSdkModeEnabled" -> {
                isSdkModeEnabled(call, result)
            }

            "doFirstTimeUse" -> {
                doFirstTimeUse(call, result)
            }

            "isFtuDone" -> {
                isFtuDone(call, result)
            }

            "getSleep" -> {
                getSleep(call, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventSink,
    ) {
        initApi()
        wrapper.addSink(arguments as Int, events)
    }

    override fun onCancel(arguments: Any?) {
        val id = arguments as? Int ?: return
        wrapper.removeSink(id)
    }

    private val searchHandler =
        object : EventChannel.StreamHandler {
            private var searchJob: Job? = null

            override fun onListen(
                arguments: Any?,
                events: EventSink,
            ) {
                initApi()

                searchJob = CoroutineScope(Dispatchers.Main).launch {
                    try {
                        wrapper.api.searchForDevice().collect {
                            events.success(gson.toJson(it))
                        }
                        events.endOfStream()
                    } catch (e: Exception) {
                        events.error(e.toString(), e.message, null)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                searchJob?.cancel()
            }
        }

    private fun createStreamingChannel(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val name = arguments[0] as String
        val identifier = arguments[1] as String
        val feature = gson.fromJson(arguments[2] as String, PolarDeviceDataType::class.java)

        if (streamingChannels[name] == null) {
            streamingChannels[name] =
                StreamingChannel(messenger, name, wrapper.api, identifier, feature)
        }

        result.success(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        val lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
        lifecycle.addObserver(
            LifecycleEventObserver { _, event ->
                when (event) {
                    Event.ON_RESUME -> {
                        wrapperInternal?.api?.foregroundEntered()
                    }

                    Event.ON_DESTROY -> {
                        shutDown()
                    }

                    else -> {}
                }
            },
        )
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivity() {}

    private fun shutDown() {
        if (wrapperInternal == null) return
        wrapper.shutDown()
    }

    private fun getAvailableOnlineStreamDataTypes(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val dataTypes = wrapper.api.getAvailableOnlineStreamDataTypes(identifier)
                result.success(gson.toJson(dataTypes))
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun getAvailableHrServiceDataTypes(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val dataTypes = wrapper.api.getAvailableHRServiceDataTypes(identifier)
                result.success(gson.toJson(dataTypes))
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun requestStreamSettings(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val feature = gson.fromJson(arguments[1] as String, PolarDeviceDataType::class.java)

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val settings = wrapper.api.requestStreamSettings(identifier, feature)
                result.success(gson.toJson(settings))
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun startRecording(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val exerciseId = arguments[1] as String
        val interval = gson.fromJson(arguments[2] as String, RecordingInterval::class.java)
        val sampleType = gson.fromJson(arguments[3] as String, SampleType::class.java)

        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.startRecording(identifier, exerciseId, interval, sampleType)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun stopRecording(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.stopRecording(identifier)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun requestRecordingStatus(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val status = wrapper.api.requestRecordingStatus(identifier)
                result.success(listOf(status.first, status.second))
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun listExercises(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val exercises = mutableListOf<String>()
                wrapper.api.listExercises(identifier).collect {
                    exercises.add(gson.toJson(it))
                }
                result.success(exercises)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun fetchExercise(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val entry = gson.fromJson(arguments[1] as String, PolarExerciseEntry::class.java)

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val data = wrapper.api.fetchExercise(identifier, entry)
                result.success(gson.toJson(data))
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun removeExercise(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val entry = gson.fromJson(arguments[1] as String, PolarExerciseEntry::class.java)

        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.removeExercise(identifier, entry)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun setLedConfig(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val config = gson.fromJson(arguments[1] as String, LedConfig::class.java)

        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.setLedConfig(identifier, config)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun doFactoryReset(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val preservePairingInformation = arguments[1] as Boolean

        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.doFactoryReset(identifier)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun enableSdkMode(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String
        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.enableSDKMode(identifier)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun disableSdkMode(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String
        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.disableSDKMode(identifier)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun isSdkModeEnabled(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val enabled = wrapper.api.isSDKModeEnabled(identifier)
                result.success(enabled)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun doFirstTimeUse(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val ftuConfig = gson.fromJson(arguments[1] as String, PolarFirstTimeUseConfig::class.java)

        CoroutineScope(Dispatchers.Main).launch {
            try {
                wrapper.api.doFirstTimeUse(identifier, ftuConfig)
                result.success(null)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun isFtuDone(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val isDone = wrapper.api.isFtuDone(identifier)
                result.success(isDone)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }

    private fun getSleep(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val fromDateStr = arguments[1] as String?
        val toDateStr = arguments[2] as String?

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val fromDate = fromDateStr?.let { java.time.ZonedDateTime.parse(it).toLocalDate() } ?: java.time.LocalDate.now().minusDays(30)
                val toDate = toDateStr?.let { java.time.ZonedDateTime.parse(it).toLocalDate() } ?: java.time.LocalDate.now()

                val data = wrapper.api.getSleep(identifier, fromDate, toDate)
                // map to inner result to match iOS JSON structure
                val results = data.map { it.result }
                val encodedData = gson.toJson(results)
                
                // Decode it into a List of Maps to send over MethodChannel
                val listType = object : com.google.gson.reflect.TypeToken<List<Map<String, Any>>>() {}.type
                val decodedData: List<Map<String, Any>> = gson.fromJson(encodedData, listType)
                result.success(decodedData)
            } catch (e: Exception) {
                result.error(e.toString(), e.message, null)
            }
        }
    }
}

class PolarWrapper(
    context: Context,
    val api: PolarBleApi =
        PolarBleApiDefaultImpl.defaultImplementation(
            context,
            PolarBleSdkFeature.values().toSet(),
        ),
    private val sinks: MutableMap<Int, EventSink> = mutableMapOf(),
) : PolarBleApiCallbackProvider {
    init {
        api.setApiCallback(this)
    }

    fun addSink(
        id: Int,
        sink: EventSink,
    ) {
        sinks[id] = sink
    }

    fun removeSink(id: Int) {
        sinks.remove(id)
    }

    private fun success(
        event: String,
        data: Any?,
    ) {
        runOnUiThread { sinks.values.forEach { it.success(mapOf("event" to event, "data" to data)) } }
    }

    fun shutDown() {
        // Do not shutdown the api if other engines are still using it
        if (sinks.isNotEmpty()) return
        try {
            api.shutDown()
        } catch (e: Exception) {
            // This will throw if the API is already shut down
        }
    }

    override fun blePowerStateChanged(powered: Boolean) {
        success("blePowerStateChanged", powered)
    }

    override fun bleSdkFeatureReady(
        identifier: String,
        feature: PolarBleSdkFeature,
    ) {
        success("sdkFeatureReady", listOf(identifier, feature.name))
    }

    override fun bleSdkFeaturesReadiness(
        identifier: String,
        ready: List<PolarBleSdkFeature>,
        unavailable: List<PolarBleSdkFeature>,
    ) {
        ready.forEach { feature ->
            success("sdkFeatureReady", listOf(identifier, feature.name))
        }
    }

    override fun deviceConnected(polarDeviceInfo: PolarDeviceInfo) {
        success("deviceConnected", gson.toJson(polarDeviceInfo))
    }

    override fun deviceConnecting(polarDeviceInfo: PolarDeviceInfo) {
        success("deviceConnecting", gson.toJson(polarDeviceInfo))
    }

    override fun deviceDisconnected(polarDeviceInfo: PolarDeviceInfo) {
        success(
            "deviceDisconnected",
            // The second argument is the `pairingError` field on iOS
            // Since Android doesn't implement that, always send false
            listOf(gson.toJson(polarDeviceInfo), false),
        )
    }

    override fun disInformationReceived(
        identifier: String,
        uuid: UUID,
        value: String,
    ) {
        success("disInformationReceived", listOf(identifier, uuid.toString(), value))
    }

    override fun disInformationReceived(
        identifier: String,
        disInfo: DisInfo,
    ) {
        success("disInformationReceived", listOf(identifier, disInfo.key, disInfo.value))
    }

    override fun batteryLevelReceived(
        identifier: String,
        level: Int,
    ) {
        success("batteryLevelReceived", listOf(identifier, level))
    }

    override fun batteryChargingStatusReceived(
        identifier: String,
        chargingStatus: ChargeState,
    ) {
        success("batteryChargingStatusReceived", listOf(identifier, chargingStatus.name))
    }

    override fun htsNotificationReceived(
        identifier: String,
        data: PolarHealthThermometerData,
    ) {
        // Do nothing
    }

    override fun powerSourcesStateReceived(
        identifier: String,
        powerSourcesState: PowerSourcesState,
    ) {
        // Not forwarded to Flutter — no-op to prevent crash (native SDK calls
        // this when device reports power source state, e.g. USB vs battery).
    }

    @Deprecated("", replaceWith = ReplaceWith(""))
    override fun hrNotificationReceived(
        identifier: String,
        data: PolarHrData.PolarHrSample,
    ) {
        // Do nothing
    }
}

class StreamingChannel(
    messenger: BinaryMessenger,
    name: String,
    private val api: PolarBleApi,
    private val identifier: String,
    private val feature: PolarDeviceDataType,
    private val channel: EventChannel = EventChannel(messenger, name),
) : EventChannel.StreamHandler {
    private var streamJob: Job? = null

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(
        arguments: Any?,
        events: EventSink,
    ) {
        // Will be null for some features
        val settings = gson.fromJson(arguments as String, PolarSensorSetting::class.java)

        val stream =
            when (feature) {
                PolarDeviceDataType.HR -> {
                    api.startHrStreaming(identifier)
                }

                PolarDeviceDataType.ECG -> {
                    api.startEcgStreaming(identifier, settings)
                }

                PolarDeviceDataType.ACC -> {
                    api.startAccStreaming(identifier, settings)
                }

                PolarDeviceDataType.PPG -> {
                    api.startPpgStreaming(identifier, settings)
                }

                PolarDeviceDataType.PPI -> {
                    api.startPpiStreaming(identifier)
                }

                PolarDeviceDataType.GYRO -> {
                    api.startGyroStreaming(identifier, settings)
                }

                PolarDeviceDataType.MAGNETOMETER -> {
                    api.startMagnetometerStreaming(
                        identifier,
                        settings,
                    )
                }

                PolarDeviceDataType.TEMPERATURE -> {
                    api.startTemperatureStreaming(
                        identifier,
                        settings,
                    )
                }

                PolarDeviceDataType.PRESSURE -> {
                    api.startPressureStreaming(identifier, settings)
                }

                PolarDeviceDataType.SKIN_TEMPERATURE -> {
                    api.startSkinTemperatureStreaming(identifier, settings)
                }

                PolarDeviceDataType.LOCATION -> {
                    api.startLocationStreaming(identifier, settings)
                }
            }

        streamJob = CoroutineScope(Dispatchers.Main).launch {
            try {
                stream.collect {
                    events.success(gson.toJson(it))
                }
                events.endOfStream()
            } catch (e: Exception) {
                events.error(e.toString(), e.message, null)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        streamJob?.cancel()
    }

    fun dispose() {
        streamJob?.cancel()
        channel.setStreamHandler(null)
    }
}
