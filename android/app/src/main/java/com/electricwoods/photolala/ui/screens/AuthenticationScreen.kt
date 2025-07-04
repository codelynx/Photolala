package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.electricwoods.photolala.R
import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.services.AuthException
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
	
	// State for showing create account dialog
	var showCreateAccountDialog by remember { mutableStateOf(false) }
	var pendingProvider by remember { mutableStateOf<AuthProvider?>(null) }
	var pendingCredential by remember { mutableStateOf<AuthCredential?>(null) }
	
	// Set up the no account found callback
	LaunchedEffect(Unit) {
		viewModel.onNoAccountFound = { provider, credential ->
			pendingProvider = provider
			pendingCredential = credential
			showCreateAccountDialog = true
		}
	}
	
	// Monitor authentication state changes - but only for Google Sign-In
	// Apple Sign-In uses the event bus mechanism in AuthenticationViewModel
	LaunchedEffect(currentUser) {
		android.util.Log.d("AuthenticationScreen", "LaunchedEffect triggered, currentUser: $currentUser")
		// Only handle Google Sign-In success here, Apple Sign-In is handled via event bus
		if (currentUser != null && currentUser!!.primaryProvider == AuthProvider.GOOGLE) {
			android.util.Log.d("AuthenticationScreen", "Google user authenticated, calling onAuthSuccess")
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
			val clipboardManager = LocalClipboardManager.current
			val context = LocalContext.current
			
			Spacer(modifier = Modifier.height(24.dp))
			Card(
				modifier = Modifier
					.fillMaxWidth()
					.clickable {
						// Copy to clipboard when clicked
						clipboardManager.setText(AnnotatedString(error))
						// Show toast
						android.widget.Toast.makeText(
							context,
							"Error message copied to clipboard",
							android.widget.Toast.LENGTH_SHORT
						).show()
					},
				colors = CardDefaults.cardColors(
					containerColor = MaterialTheme.colorScheme.errorContainer
				)
			) {
				Column(
					modifier = Modifier.padding(16.dp)
				) {
					SelectionContainer {
						Text(
							text = error,
							color = MaterialTheme.colorScheme.onErrorContainer
						)
					}
					Spacer(modifier = Modifier.height(8.dp))
					Text(
						text = "Tap to copy",
						fontSize = 12.sp,
						color = MaterialTheme.colorScheme.onErrorContainer.copy(alpha = 0.6f),
						modifier = Modifier.align(Alignment.End)
					)
				}
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
	
	// Show create account dialog
	if (showCreateAccountDialog && pendingProvider != null) {
		AlertDialog(
			onDismissRequest = {
				showCreateAccountDialog = false
				pendingProvider = null
			},
			title = { 
				SelectionContainer {
					Text("No Account Found")
				}
			},
			text = {
				SelectionContainer {
					Text("No account found with ${pendingProvider?.displayName}. Would you like to create a new account?")
				}
			},
			confirmButton = {
				TextButton(
					onClick = {
						showCreateAccountDialog = false
						// Use the existing credential if available to avoid re-authentication
						val credential = pendingCredential
						if (credential != null) {
							viewModel.createAccountWithCredential(
								credential = credential,
								onSuccess = onAuthSuccess
							)
						} else {
							// Fallback to re-authentication if no credential is available
							pendingProvider?.let { provider ->
								viewModel.authenticate(
									provider = provider,
									isSignUp = true,
									onSuccess = onAuthSuccess
								)
							}
						}
						pendingProvider = null
						pendingCredential = null
					}
				) {
					Text("Create Account")
				}
			},
			dismissButton = {
				TextButton(
					onClick = {
						showCreateAccountDialog = false
						pendingProvider = null
						pendingCredential = null
					}
				) {
					Text("Cancel")
				}
			}
		)
	}
}