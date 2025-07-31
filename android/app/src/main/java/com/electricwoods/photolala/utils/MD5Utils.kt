package com.electricwoods.photolala.utils

import java.security.MessageDigest

/**
 * MD5 utility functions for PhotoDigest
 */
object MD5Utils {
	/**
	 * Computes MD5 hash of a string
	 */
	fun md5(input: String): String {
		val md = MessageDigest.getInstance("MD5")
		val digest = md.digest(input.toByteArray())
		return digest.joinToString("") { "%02x".format(it) }
	}
	
	/**
	 * Computes MD5 hash of a byte array
	 */
	fun md5(input: ByteArray): String {
		val md = MessageDigest.getInstance("MD5")
		val digest = md.digest(input)
		return digest.joinToString("") { "%02x".format(it) }
	}
	
	/**
	 * Computes MD5 hash of a file
	 */
	suspend fun md5File(file: java.io.File): String {
		return kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
			val md = MessageDigest.getInstance("MD5")
			file.inputStream().use { input ->
				val buffer = ByteArray(8192)
				var bytesRead: Int
				while (input.read(buffer).also { bytesRead = it } != -1) {
					md.update(buffer, 0, bytesRead)
				}
			}
			md.digest().joinToString("") { "%02x".format(it) }
		}
	}
}