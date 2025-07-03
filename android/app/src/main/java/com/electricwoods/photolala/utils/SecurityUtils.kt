package com.electricwoods.photolala.utils

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object SecurityUtils {
	private const val KEYSTORE_ALIAS = "PhotolalaUserKey"
	private const val ANDROID_KEYSTORE = "AndroidKeyStore"
	private const val TRANSFORMATION = "AES/GCM/NoPadding"
	private const val GCM_TAG_LENGTH = 128
	
	/**
	 * Encrypts a string using Android Keystore
	 * @return Base64 encoded encrypted data with IV prepended
	 */
	fun encrypt(context: Context, plainText: String): String {
		val key = getOrCreateKey()
		val cipher = Cipher.getInstance(TRANSFORMATION)
		cipher.init(Cipher.ENCRYPT_MODE, key)
		
		val iv = cipher.iv
		val encryptedBytes = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
		
		// Combine IV and encrypted data
		val combined = ByteArray(iv.size + encryptedBytes.size)
		System.arraycopy(iv, 0, combined, 0, iv.size)
		System.arraycopy(encryptedBytes, 0, combined, iv.size, encryptedBytes.size)
		
		return Base64.encodeToString(combined, Base64.NO_WRAP)
	}
	
	/**
	 * Decrypts a Base64 encoded string using Android Keystore
	 * @param encryptedData Base64 encoded data with IV prepended
	 */
	fun decrypt(context: Context, encryptedData: String): String {
		val key = getOrCreateKey()
		val combined = Base64.decode(encryptedData, Base64.NO_WRAP)
		
		// Extract IV (first 12 bytes for GCM)
		val iv = ByteArray(12)
		val cipherText = ByteArray(combined.size - 12)
		System.arraycopy(combined, 0, iv, 0, 12)
		System.arraycopy(combined, 12, cipherText, 0, cipherText.size)
		
		val cipher = Cipher.getInstance(TRANSFORMATION)
		val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
		cipher.init(Cipher.DECRYPT_MODE, key, spec)
		
		val decryptedBytes = cipher.doFinal(cipherText)
		return String(decryptedBytes, Charsets.UTF_8)
	}
	
	/**
	 * Gets existing key or creates a new one in Android Keystore
	 */
	private fun getOrCreateKey(): SecretKey {
		val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
		keyStore.load(null)
		
		// Check if key already exists
		if (keyStore.containsAlias(KEYSTORE_ALIAS)) {
			val keyEntry = keyStore.getEntry(KEYSTORE_ALIAS, null) as? KeyStore.SecretKeyEntry
			return keyEntry?.secretKey ?: createKey()
		}
		
		return createKey()
	}
	
	/**
	 * Creates a new AES key in Android Keystore
	 */
	private fun createKey(): SecretKey {
		val keyGenerator = KeyGenerator.getInstance(
			KeyProperties.KEY_ALGORITHM_AES,
			ANDROID_KEYSTORE
		)
		
		val keyGenParameterSpec = KeyGenParameterSpec.Builder(
			KEYSTORE_ALIAS,
			KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
		)
			.setBlockModes(KeyProperties.BLOCK_MODE_GCM)
			.setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
			.setKeySize(256)
			.build()
		
		keyGenerator.init(keyGenParameterSpec)
		return keyGenerator.generateKey()
	}
	
	/**
	 * Checks if a key exists in the keystore
	 */
	fun hasKey(): Boolean {
		return try {
			val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
			keyStore.load(null)
			keyStore.containsAlias(KEYSTORE_ALIAS)
		} catch (e: Exception) {
			false
		}
	}
	
	/**
	 * Deletes the key from keystore (use with caution)
	 */
	fun deleteKey() {
		try {
			val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
			keyStore.load(null)
			keyStore.deleteEntry(KEYSTORE_ALIAS)
		} catch (e: Exception) {
			// Ignore errors when deleting
		}
	}
}