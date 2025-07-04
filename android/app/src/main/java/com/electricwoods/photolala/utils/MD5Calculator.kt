package com.electricwoods.photolala.utils

import java.io.InputStream
import java.security.MessageDigest

object MD5Calculator {
	/**
	 * Calculate MD5 hash from an input stream
	 */
	fun calculate(inputStream: InputStream): String {
		val md = MessageDigest.getInstance("MD5")
		val buffer = ByteArray(8192)
		var bytesRead: Int
		
		while (inputStream.read(buffer).also { bytesRead = it } != -1) {
			md.update(buffer, 0, bytesRead)
		}
		
		return md.digest().joinToString("") { "%02x".format(it) }
	}
	
	/**
	 * Calculate MD5 hash from a byte array
	 */
	fun calculate(data: ByteArray): String {
		val md = MessageDigest.getInstance("MD5")
		return md.digest(data).joinToString("") { "%02x".format(it) }
	}
}