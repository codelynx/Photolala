package com.electricwoods.photolala.data.local

import androidx.room.TypeConverter
import com.electricwoods.photolala.models.ArchiveStatus
import com.electricwoods.photolala.models.BackupState
import com.electricwoods.photolala.models.ColorFlag
import com.electricwoods.photolala.models.PhotoSource
import java.util.Date

class Converters {
	@TypeConverter
	fun fromTimestamp(value: Long?): Date? {
		return value?.let { Date(it) }
	}

	@TypeConverter
	fun dateToTimestamp(date: Date?): Long? {
		return date?.time
	}

	@TypeConverter
	fun fromPhotoSource(source: PhotoSource): String {
		return source.name
	}

	@TypeConverter
	fun toPhotoSource(source: String): PhotoSource {
		return PhotoSource.valueOf(source)
	}

	@TypeConverter
	fun fromArchiveStatus(status: ArchiveStatus): String {
		return status.name
	}

	@TypeConverter
	fun toArchiveStatus(status: String): ArchiveStatus {
		return ArchiveStatus.valueOf(status)
	}

	@TypeConverter
	fun fromBackupState(state: BackupState): String {
		return state.name
	}

	@TypeConverter
	fun toBackupState(state: String): BackupState {
		return BackupState.valueOf(state)
	}

	@TypeConverter
	fun fromColorFlag(flag: ColorFlag?): Int? {
		return flag?.value
	}

	@TypeConverter
	fun toColorFlag(value: Int?): ColorFlag? {
		return value?.let { ColorFlag.fromValue(it) }
	}

	@TypeConverter
	fun fromColorFlagSet(flags: Set<ColorFlag>): String {
		return flags.joinToString(",") { it.value.toString() }
	}

	@TypeConverter
	fun toColorFlagSet(flags: String): Set<ColorFlag> {
		if (flags.isEmpty()) return emptySet()
		return flags.split(",")
			.mapNotNull { it.toIntOrNull() }
			.mapNotNull { ColorFlag.fromValue(it) }
			.toSet()
	}
}