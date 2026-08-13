package com.alandaitch.anden.util

import com.alandaitch.anden.data.model.Arrival

// Agrupa arribos por ramal y sentido, preservando el orden de llegada.
object ArrivalGrouping {
    data class Group(
        val id: String,
        val ramalName: String,
        val direction: Int,
        val destinationName: String,
        val arrivals: List<Arrival>
    )

    fun byRamalDirection(arrivals: List<Arrival>): List<Group> {
        val order = mutableListOf<String>()
        val buckets = mutableMapOf<String, MutableList<Arrival>>()
        for (a in arrivals) {
            val key = "${a.ramalName}#${a.direction}"
            if (buckets[key] == null) {
                order.add(key)
                buckets[key] = mutableListOf()
            }
            buckets[key]!!.add(a)
        }
        return order.map { key ->
            val items = buckets[key] ?: emptyList()
            val first = items.firstOrNull()
            Group(
                id = key,
                ramalName = first?.ramalName ?: "",
                direction = first?.direction ?: 0,
                destinationName = first?.destinationName ?: "",
                arrivals = items
            )
        }
    }
}
