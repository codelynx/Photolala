package com.electricwoods.photolala

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.electricwoods.photolala.navigation.PhotolalaNavigation
import com.electricwoods.photolala.services.IdentityManager
import com.electricwoods.photolala.ui.theme.PhotolalaTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
	
	@Inject
	lateinit var identityManager: IdentityManager
	
	// Google Sign-In launcher
	val googleSignInLauncher = registerForActivityResult(
		ActivityResultContracts.StartActivityForResult()
	) { result ->
		// Pass the result to navigation
		PhotolalaNavigation.handleGoogleSignInResult(result.data)
	}
	
	private val requestPermissionLauncher = registerForActivityResult(
		ActivityResultContracts.RequestPermission()
	) { isGranted ->
		if (isGranted) {
			// Permission granted, the UI will automatically refresh
		}
	}
	
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		enableEdgeToEdge()
		
		// Check if this is an Apple Sign-In callback
		handleAppleSignInCallbackIfNeeded(intent)
		
		// Request permission if not granted
		requestPhotoPermission()
		
		setContent {
			PhotolalaTheme {
				PhotolalaNavigation(
					googleSignInLauncher = googleSignInLauncher
				)
			}
		}
	}
	
	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		handleAppleSignInCallbackIfNeeded(intent)
	}
	
	private fun handleAppleSignInCallbackIfNeeded(intent: Intent?) {
		intent?.data?.let { uri ->
			android.util.Log.d("MainActivity", "Received deep link: $uri")
			if (uri.scheme == "photolala" && uri.host == "auth" && uri.path == "/apple") {
				android.util.Log.d("MainActivity", "=== APPLE DEEP LINK DETECTED ===")
				android.util.Log.d("MainActivity", "Processing Apple Sign-In callback...")
				lifecycleScope.launch {
					val result = identityManager.handleAppleSignInCallback(uri)
					android.util.Log.d("MainActivity", "Apple callback result: ${if (result.isSuccess) "SUCCESS" else "FAILURE: ${result.exceptionOrNull()?.message}"}")
				}
			}
		}
	}
	
	private fun requestPhotoPermission() {
		val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			Manifest.permission.READ_MEDIA_IMAGES
		} else {
			Manifest.permission.READ_EXTERNAL_STORAGE
		}
		
		when {
			ContextCompat.checkSelfPermission(
				this,
				permission
			) == PackageManager.PERMISSION_GRANTED -> {
				// Permission already granted
			}
			shouldShowRequestPermissionRationale(permission) -> {
				// Show explanation before requesting
				requestPermissionLauncher.launch(permission)
			}
			else -> {
				// Request permission
				requestPermissionLauncher.launch(permission)
			}
		}
	}
}