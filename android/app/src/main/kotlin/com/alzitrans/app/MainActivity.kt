package com.alzitrans.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Locale

class MainActivity: FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.alzitrans.app/maps"
    private val ASSISTANT_CHANNEL = "com.alzitrans.app/assistant"
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val TAG = "AlzitransAssistant"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Canal para abrir mapas
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openMaps") {
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                if (latitude != null && longitude != null) {
                    val uri = Uri.parse("geo:$latitude,$longitude?q=$latitude,$longitude(Parada de bus)")
                    val intent = Intent(Intent.ACTION_VIEW, uri)
                    intent.setPackage("com.google.android.apps.maps")
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        result.success(true)
                    } else {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=$latitude,$longitude"))
                        startActivity(browserIntent)
                        result.success(true)
                    }
                } else {
                    result.error("INVALID_COORDS", "Coordenadas inválidas", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Canal para Assistant - obtener tiempos de bus
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSISTANT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBusTimes" -> {
                    // Obtener tiempos del widget
                    val widgetData = HomeWidgetPlugin.getData(this)
                    val arrivalCount = widgetData.getInt("widget_arrival_count", 0)
                    
                    if (arrivalCount == 0) {
                        result.success("No tienes paradas favoritas configuradas")
                    } else {
                        val response = StringBuilder()
                        val stopName = widgetData.getString("widget_stop_name", "tu parada") ?: "tu parada"
                        response.append("En $stopName: ")
                        
                        for (i in 0 until minOf(arrivalCount, 3)) {
                            val line = widgetData.getString("widget_line_$i", "") ?: ""
                            val dest = widgetData.getString("widget_dest_$i", "") ?: ""
                            val time = widgetData.getString("widget_time_$i", "") ?: ""
                            if (line.isNotEmpty()) {
                                response.append("Línea $line hacia $dest en $time. ")
                            }
                        }
                        result.success(response.toString())
                    }
                }
                "speakBusTimes" -> {
                    val text = getBusTimesText()
                    speak(text)
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate - Inicializando TTS")
        // Inicializar TTS
        tts = TextToSpeech(this, this)
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent - Nuevo intent recibido: ${intent.data}")
        setIntent(intent) // Importante: actualizar el intent
        handleIntent(intent)
    }
    
    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
    
    override fun onInit(status: Int) {
        Log.d(TAG, "TTS onInit - status: $status")
        if (status == TextToSpeech.SUCCESS) {
            val result = tts?.setLanguage(Locale("es", "ES"))
            ttsReady = result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED
            Log.d(TAG, "TTS listo: $ttsReady")
        }
    }
    
    private fun speak(text: String) {
        Log.d(TAG, "Intentando hablar: $text")
        if (ttsReady && tts != null) {
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "bus_times")
            Log.d(TAG, "TTS hablando...")
        } else {
            Log.d(TAG, "TTS no está listo, esperando...")
            // Esperar un poco y reintentar
            Handler(Looper.getMainLooper()).postDelayed({
                if (tts != null) {
                    tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "bus_times")
                }
            }, 500)
        }
    }
    
    private fun getBusTimesText(): String {
        val widgetData = HomeWidgetPlugin.getData(this)
        val stopName = widgetData.getString("widget_stop_name", null)
        val lineDestination = widgetData.getString("widget_line_destination", null)
        val arrivalTime = widgetData.getString("widget_arrival_time", null)
        
        if (stopName == null || stopName == "Sin parada favorita") {
            return "No tienes paradas favoritas. Abre Alzitrans y añade una parada."
        }
        
        if (lineDestination == null || lineDestination == "Sin datos") {
            return "No hay información de buses para $stopName en este momento."
        }
        
        // Formatear tiempo para habla natural
        val timeSpoken = when {
            arrivalTime == null || arrivalTime == "--" -> "sin tiempo estimado"
            arrivalTime.contains("Llegando", ignoreCase = true) -> "está llegando ahora"
            arrivalTime.contains("min") -> "llega en $arrivalTime"
            else -> "llega en $arrivalTime"
        }
        
        return "En $stopName: $lineDestination $timeSpoken."
    }
    
    private fun handleIntent(intent: Intent) {
        val data = intent.data
        Log.d(TAG, "handleIntent - data: $data, scheme: ${data?.scheme}, host: ${data?.host}")
        
        if (data != null && data.scheme == "alzitrans") {
            // Deep link desde Google Assistant
            when (data.host) {
                "bus_times" -> {
                    Log.d(TAG, "Procesando bus_times")
                    // Obtener y hablar los tiempos de bus
                    val text = getBusTimesText()
                    Log.d(TAG, "Texto a hablar: $text")
                    Toast.makeText(this, text, Toast.LENGTH_LONG).show()
                    speak(text)
                }
                "favorites" -> {
                    // Navegar a favoritos - Flutter manejará esto
                }
            }
        }
    }
}
