package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.electricwoods.photolala.R
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.services.IdentityManager
import com.electricwoods.photolala.ui.viewmodels.AuthenticationViewModel

@Composable
fun AuthenticationScreen(
	isSignUp: Boolean,
	onAuthSuccess: () -> Unit,
	onCancel: () -> Unit,
	viewModel: AuthenticationViewModel = hiltViewModel()
) {
	val identityManager = viewModel.identityManager
	val isLoading by identityManager.isLoading.collectAsStateWithLifecycle()
	val errorMessage by identityManager.errorMessage.collectAsStateWithLifecycle()
	val currentUser by identityManager.currentUser.collectAsStateWithLifecycle()
	
	// Monitor authentication state changes
	LaunchedEffect(currentUser) {
		android.util.Log.d("AuthenticationScreen", "LaunchedEffect triggered, currentUser: $currentUser")
		if (currentUser != null) {
			android.util.Log.d("AuthenticationScreen", "User authenticated, calling onAuthSuccess")
			// User successfully authenticated, trigger success callback
			onAuthSuccess()
		}
	}
	
	Column(
		modifier = Modifier
			.fillMaxSize()
			.padding(24.dp),
		horizontalAlignment = Alignment.CenterHorizontally,
		verticalArrangement = Arrangement.Center
	) {
		// Logo or icon (placeholder for now)
		Icon(
			painter = painterResource(id = R.drawable.ic_launcher_foreground),
			contentDescription = null,
			modifier = Modifier.size(80.dp),
			tint = MaterialTheme.colorScheme.primary
		)
		
		Spacer(modifier = Modifier.height(32.dp))
		
		// Title
		Text(
			text = if (isSignUp) "Create Account" else "Sign In",
			fontSize = 28.sp,
			fontWeight = FontWeight.Bold
		)
		
		Spacer(modifier = Modifier.height(8.dp))
		
		// Subtitle
		Text(
			text = if (isSignUp) {
				"Create an account to backup your photos and access them from any device"
			} else {
				"Sign in to access your backed up photos"
			},
			fontSize = 16.sp,
			color = MaterialTheme.colorScheme.onSurfaceVariant,
			textAlign = TextAlign.Center,
			modifier = Modifier.padding(horizontal = 32.dp)
		)
		
		Spacer(modifier = Modifier.height(48.dp))
		
		// Google Sign In Button
		ElevatedButton(
			onClick = {
				viewModel.authenticate(
					provider = AuthProvider.GOOGLE,
					isSignUp = isSignUp,
					onSuccess = onAuthSuccess
				)
			},
			modifier = Modifier
				.fillMaxWidth()
				.height(56.dp),
			enabled = !isLoading,
			colors = ButtonDefaults.elevatedButtonColors(
				containerColor = MaterialTheme.colorScheme.surface
			)
		) {
			Row(
				verticalAlignment = Alignment.CenterVertically,
				horizontalArrangement = Arrangement.Center
			) {
				Icon(
					painter = painterResource(id = R.drawable.ic_google_logo),
					contentDescription = null,
					modifier = Modifier.size(24.dp),
					tint = Color.Unspecified // Keep original Google colors
				)
				Spacer(modifier = Modifier.width(12.dp))
				Text(
					text = if (isSignUp) "Continue with Google" else "Sign in with Google",
					fontSize = 16.sp
				)
			}
		}
		
		Spacer(modifier = Modifier.height(16.dp))
		
		// Apple Sign In Button
		Button(
			onClick = {
				viewModel.authenticate(
					provider = AuthProvider.APPLE,
					isSignUp = isSignUp,
					onSuccess = onAuthSuccess
				)
			},
			modifier = Modifier
				.fillMaxWidth()
				.height(56.dp),
			enabled = !isLoading,
			colors = ButtonDefaults.buttonColors(
				containerColor = Color.Black,
				contentColor = Color.White
			)
		) {
			Row(
				verticalAlignment = Alignment.CenterVertically,
				horizontalArrangement = Arrangement.Center
			) {
				Icon(
					painter = painterResource(id = R.drawable.ic_apple_logo),
					contentDescription = null,
					modifier = Modifier.size(24.dp),
					tint = Color.White
				)
				Spacer(modifier = Modifier.width(12.dp))
				Text(
					text = if (isSignUp) "Continue with Apple" else "Sign in with Apple",
					fontSize = 16.sp,
					color = Color.White
				)
			}
		}
		
		// Error message
		errorMessage?.let { error ->
			Spacer(modifier = Modifier.height(24.dp))
			Card(
				modifier = Modifier.fillMaxWidth(),
				colors = CardDefaults.cardColors(
					containerColor = MaterialTheme.colorScheme.errorContainer
				)
			) {
				Text(
					text = error,
					modifier = Modifier.padding(16.dp),
					color = MaterialTheme.colorScheme.onErrorContainer
				)
			}
		}
		
		Spacer(modifier = Modifier.weight(1f))
		
		// Cancel button
		TextButton(
			onClick = onCancel,
			modifier = Modifier.fillMaxWidth()
		) {
			Text("Cancel")
		}
		
		// Loading indicator
		if (isLoading) {
			Box(
				modifier = Modifier
					.fillMaxSize()
					.padding(24.dp),
				contentAlignment = Alignment.Center
			) {
				CircularProgressIndicator()
			}
		}
	}
}