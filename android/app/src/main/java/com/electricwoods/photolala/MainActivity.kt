package com.electricwoods.photolala

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import androidx.core.content.ContextCompat
import com.electricwoods.photolala.navigation.PhotolalaNavigation
import com.electricwoods.photolala.ui.theme.PhotolalaTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
	
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