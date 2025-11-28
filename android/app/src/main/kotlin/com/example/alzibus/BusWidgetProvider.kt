package com.example.alzibus

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
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
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.bus_widget)
            
            // Obtener datos usando HomeWidgetPlugin (la manera correcta)
            val widgetData = HomeWidgetPlugin.getData(context)
            
            val stopName = widgetData.getString("widget_stop_name", "Sin parada favorita") ?: "Sin parada favorita"
            val lineDestination = widgetData.getString("widget_line_destination", "Toca para configurar") ?: "Toca para configurar"
            val arrivalTime = widgetData.getString("widget_arrival_time", "--") ?: "--"
            val lastUpdate = widgetData.getString("widget_last_update", "--:--") ?: "--:--"
            
            // Actualizar vistas
            views.setTextViewText(R.id.stop_name, "🚏 $stopName")
            views.setTextViewText(R.id.line_destination, lineDestination)
            views.setTextViewText(R.id.arrival_time, "⏱️ $arrivalTime")
            views.setTextViewText(R.id.last_update, "Actualizado: $lastUpdate")
            
            // Color del tiempo según urgencia
            val timeColor = when {
                arrivalTime.contains("llegando", ignoreCase = true) -> 0xFFF44336.toInt() // Rojo
                arrivalTime.contains("1 min") || arrivalTime.contains("2 min") -> 0xFFFF9800.toInt() // Naranja
                else -> 0xFF4CAF50.toInt() // Verde
            }
            views.setTextColor(R.id.arrival_time, timeColor)
            
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
