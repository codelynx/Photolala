package com.electricwoods.photolala.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.electricwoods.photolala.data.local.dao.PhotoDao
import com.electricwoods.photolala.data.local.dao.TagDao
import com.electricwoods.photolala.data.local.entities.PhotoEntity
import com.electricwoods.photolala.data.local.entities.TagEntity

@Database(
	entities = [
		PhotoEntity::class,
		TagEntity::class
	],
	version = 3,
	exportSchema = false
)
@TypeConverters(Converters::class)
abstract class PhotolalaDatabase : RoomDatabase() {
	abstract fun photoDao(): PhotoDao
	abstract fun tagDao(): TagDao
}