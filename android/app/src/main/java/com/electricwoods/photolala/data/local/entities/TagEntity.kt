package com.electricwoods.photolala.data.local.entities

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.electricwoods.photolala.models.ColorFlag

@Entity(
	tableName = "tags",
	indices = [
		Index(value = ["photoId"]),
		Index(value = ["photoId", "colorFlag"], unique = true)
	]
)
data class TagEntity(
	@PrimaryKey(autoGenerate = true)
	val id: Long = 0,
	val photoId: String,
	val colorFlag: ColorFlag,
	val timestamp: Long
)