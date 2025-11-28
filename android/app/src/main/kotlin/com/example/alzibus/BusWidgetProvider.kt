package com.example.alzibus

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.view.View
import android.graphics.Color
import es.antonborri.home_widget.HomeWidgetPlugin

class BusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget habilitado por primera vez
    }

    override fun onDisabled(context: Context) {
        // Último widget eliminado
    }

    companion object {
        // Colores para las líneas de bus
        private val lineColors = mapOf(
            "L1" to Color.parseColor("#E53935"),  // Rojo
            "L2" to Color.parseColor("#1E88E5"),  // Azul
            "L3" to Color.parseColor("#43A047"),  // Verde
            "L4" to Color.parseColor("#FB8C00"),  // Naranja
            "L5" to Color.parseColor("#8E24AA"),  // Púrpura
            "L6" to Color.parseColor("#00ACC1"),  // Cyan
            "C2" to Color.parseColor("#F79529")   // Naranja Renfe
        )
        
        fun getLineColor(line: String): Int {
            return lineColors[line.uppercase()] ?: Color.parseColor("#2196F3")
        }
        
        fun getTimeColor(time: String): Int {
            return when {
                time.contains("llegando", ignoreCase = true) || time.contains("!") -> Color.parseColor("#F44336") // Rojo
                time.contains("1 min") || time.contains("2 min") || time.contains("3 min") -> Color.parseColor("#FF9800") // Naranja
                else -> Color.parseColor("#4CAF50") // Verde
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.bus_widget)
            
            // Obtener datos usando HomeWidgetPlugin
            val widgetData = HomeWidgetPlugin.getData(context)
            
            // Obtener número de llegadas disponibles
            val arrivalCount = widgetData.getInt("widget_arrival_count", 0)
            val lastUpdate = widgetData.getString("widget_last_update", "--:--") ?: "--:--"
            
            // Actualizar última actualización
            views.setTextViewText(R.id.last_update, "🔄 $lastUpdate")
            
            if (arrivalCount == 0) {
                // Mostrar estado vacío
                views.setViewVisibility(R.id.arrival_row_1, View.GONE)
                views.setViewVisibility(R.id.arrival_row_2, View.GONE)
                views.setViewVisibility(R.id.arrival_row_3, View.GONE)
                views.setViewVisibility(R.id.empty_state, View.VISIBLE)
                
                val emptyText = widgetData.getString("widget_empty_text", "Sin favoritos") ?: "Sin favoritos"
                views.setTextViewText(R.id.empty_state, emptyText)
            } else {
                views.setViewVisibility(R.id.empty_state, View.GONE)
                
                // Llegada 1
                if (arrivalCount >= 1) {
                    views.setViewVisibility(R.id.arrival_row_1, View.VISIBLE)
                    val line1 = widgetData.getString("widget_line_1", "L1") ?: "L1"
                    val dest1 = widgetData.getString("widget_dest_1", "") ?: ""
                    val time1 = widgetData.getString("widget_time_1", "--") ?: "--"
                    
                    views.setTextViewText(R.id.line_1, line1)
                    views.setTextViewText(R.id.destination_1, dest1)
                    views.setTextViewText(R.id.time_1, time1)
                    views.setTextColor(R.id.time_1, getTimeColor(time1))
                    views.setInt(R.id.line_1, "setBackgroundColor", getLineColor(line1))
                } else {
                    views.setViewVisibility(R.id.arrival_row_1, View.GONE)
                }
                
                // Llegada 2
                if (arrivalCount >= 2) {
                    views.setViewVisibility(R.id.arrival_row_2, View.VISIBLE)
                    val line2 = widgetData.getString("widget_line_2", "L2") ?: "L2"
                    val dest2 = widgetData.getString("widget_dest_2", "") ?: ""
                    val time2 = widgetData.getString("widget_time_2", "--") ?: "--"
                    
                    views.setTextViewText(R.id.line_2, line2)
                    views.setTextViewText(R.id.destination_2, dest2)
                    views.setTextViewText(R.id.time_2, time2)
                    views.setTextColor(R.id.time_2, getTimeColor(time2))
                    views.setInt(R.id.line_2, "setBackgroundColor", getLineColor(line2))
                } else {
                    views.setViewVisibility(R.id.arrival_row_2, View.GONE)
                }
                
                // Llegada 3
                if (arrivalCount >= 3) {
                    views.setViewVisibility(R.id.arrival_row_3, View.VISIBLE)
                    val line3 = widgetData.getString("widget_line_3", "L3") ?: "L3"
                    val dest3 = widgetData.getString("widget_dest_3", "") ?: ""
                    val time3 = widgetData.getString("widget_time_3", "--") ?: "--"
                    
                    views.setTextViewText(R.id.line_3, line3)
                    views.setTextViewText(R.id.destination_3, dest3)
                    views.setTextViewText(R.id.time_3, time3)
                    views.setTextColor(R.id.time_3, getTimeColor(time3))
                    views.setInt(R.id.line_3, "setBackgroundColor", getLineColor(line3))
                } else {
                    views.setViewVisibility(R.id.arrival_row_3, View.GONE)
                }
            }
            
            // Intent para abrir la app al tocar el widget
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            // Actualizar widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
