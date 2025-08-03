package com.electricwoods.photolala.ui.screens

import androidx.compose.animation.*
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.electricwoods.photolala.R
import com.electricwoods.photolala.models.PhotolalaUser
import com.electricwoods.photolala.ui.theme.PhotolalaTheme
import com.electricwoods.photolala.ui.viewmodels.WelcomeViewModel

@Composable
fun WelcomeScreen(
	onBrowsePhotosClick: () -> Unit = {},
	onCloudBrowserClick: () -> Unit = {},
	onSignInClick: () -> Unit = {},
	onCreateAccountClick: () -> Unit = {},
	onAccountSettingsClick: () -> Unit = {},
	viewModel: WelcomeViewModel = hiltViewModel()
) {
	val currentUser by viewModel.currentUser.collectAsStateWithLifecycle()
	val isSignedIn by viewModel.isSignedIn.collectAsStateWithLifecycle()
	
	// Debug logging
	LaunchedEffect(isSignedIn, currentUser) {
		android.util.Log.d("WelcomeScreen", "=== WELCOME SCREEN STATE ===")
		android.util.Log.d("WelcomeScreen", "isSignedIn: $isSignedIn")
		android.util.Log.d("WelcomeScreen", "currentUser: ${currentUser?.displayName ?: "null"}")
		android.util.Log.d("WelcomeScreen", "currentUser details: $currentUser")
	}
	
	// Success message state
	var showSignInSuccess by remember { mutableStateOf(false) }
	var signInSuccessMessage by remember { mutableStateOf("") }
	
	// Monitor sign-in status changes
	LaunchedEffect(isSignedIn, currentUser) {
		if (isSignedIn && currentUser != null && !showSignInSuccess) {
			signInSuccessMessage = "Welcome, ${currentUser!!.displayName}!"
			showSignInSuccess = true
			
			// Hide success message after 3 seconds
			kotlinx.coroutines.delay(3000)
			showSignInSuccess = false
		}
	}
	
	Box(
		modifier = Modifier.fillMaxSize(),
		contentAlignment = Alignment.Center
	) {
		Column(
			modifier = Modifier
				.widthIn(max = 400.dp)
				.padding(horizontal = 32.dp),
			verticalArrangement = Arrangement.Center,
			horizontalAlignment = Alignment.CenterHorizontally
		) {
		// App icon
		Image(
			painter = painterResource(id = R.drawable.app_icon),
			contentDescription = "Photolala",
			modifier = Modifier.size(100.dp)
		)
		
		Spacer(modifier = Modifier.height(16.dp))
		
		// Welcome text
		Text(
			text = "Welcome to Photolala",
			style = MaterialTheme.typography.headlineMedium,
			textAlign = TextAlign.Center
		)
		
		Spacer(modifier = Modifier.height(8.dp))
		
		Text(
			text = if (isSignedIn) {
				"Welcome back! Browse your local photos or access cloud storage"
			} else {
				"Welcome! Browse your local photos or sign in for cloud features"
			},
			style = MaterialTheme.typography.bodyLarge,
			textAlign = TextAlign.Center,
			color = MaterialTheme.colorScheme.onSurfaceVariant
		)
		
		// Show sign-in status if signed in
		if (isSignedIn && currentUser != null) {
			Spacer(modifier = Modifier.height(24.dp))
			SignedInCard(
				user = currentUser!!,
				onSignOut = viewModel::signOut,
				onAccountSettings = onAccountSettingsClick
			)
		}
		
		Spacer(modifier = Modifier.height(32.dp))
		
		// Local browser button
		Button(
			onClick = onBrowsePhotosClick,
			modifier = Modifier
				.fillMaxWidth()
				.height(48.dp),
			shape = RoundedCornerShape(24.dp),
			colors = ButtonDefaults.buttonColors(
				containerColor = MaterialTheme.colorScheme.primary
			)
		) {
			Icon(
				imageVector = Icons.Default.Folder,
				contentDescription = null,
				modifier = Modifier.size(20.dp)
			)
			Spacer(modifier = Modifier.width(8.dp))
			Text("Local Browser", fontSize = 16.sp)
		}
		
		Spacer(modifier = Modifier.height(12.dp))
		
		// Cloud browser button (enabled if signed in)
		OutlinedButton(
			onClick = onCloudBrowserClick,
			modifier = Modifier
				.fillMaxWidth()
				.height(48.dp),
			shape = RoundedCornerShape(24.dp),
			enabled = isSignedIn,
			border = BorderStroke(
				width = 1.dp,
				color = if (isSignedIn) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.12f)
			)
		) {
			Icon(
				imageVector = Icons.Default.Cloud,
				contentDescription = null,
				modifier = Modifier.size(20.dp)
			)
			Spacer(modifier = Modifier.width(8.dp))
			Text(
				text = if (isSignedIn) "Cloud Browser" else "Cloud Browser (Sign In Required)",
				fontSize = 16.sp
			)
		}
		
		// Sign in/Create account section
		if (!isSignedIn) {
			Spacer(modifier = Modifier.height(24.dp))
			
			HorizontalDivider(
				modifier = Modifier.padding(horizontal = 32.dp),
				color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
			)
			
			Spacer(modifier = Modifier.height(16.dp))
			
			Text(
				text = "Backup and sync your photos",
				style = MaterialTheme.typography.bodyMedium,
				textAlign = TextAlign.Center,
				color = MaterialTheme.colorScheme.onSurfaceVariant
			)
			
			Spacer(modifier = Modifier.height(12.dp))
			
			// Sign In button
			Button(
				onClick = onSignInClick,
				modifier = Modifier
					.fillMaxWidth()
					.height(48.dp),
				shape = RoundedCornerShape(24.dp),
				colors = ButtonDefaults.buttonColors(
					containerColor = MaterialTheme.colorScheme.primary
				)
			) {
				Text("Sign In", fontSize = 16.sp)
			}
			
			Spacer(modifier = Modifier.height(8.dp))
			
			// Create Account button
			TextButton(
				onClick = onCreateAccountClick,
				modifier = Modifier.fillMaxWidth()
			) {
				Text("Create Account")
			}
		}
		}
		
		// Success message overlay
		AnimatedVisibility(
			visible = showSignInSuccess,
			enter = slideInVertically(
				initialOffsetY = { -it },
				animationSpec = tween(300, easing = FastOutSlowInEasing)
			) + fadeIn(
				animationSpec = tween(300)
			),
			exit = slideOutVertically(
				targetOffsetY = { -it },
				animationSpec = tween(300, easing = FastOutSlowInEasing)
			) + fadeOut(
				animationSpec = tween(300)
			),
			modifier = Modifier.align(Alignment.TopCenter)
		) {
			Card(
				modifier = Modifier
					.padding(top = 48.dp)
					.padding(horizontal = 24.dp),
				shape = RoundedCornerShape(8.dp),
				colors = CardDefaults.cardColors(
					containerColor = Color(0xFF4CAF50).copy(alpha = 0.1f)
				),
				border = BorderStroke(1.dp, Color(0xFF4CAF50).copy(alpha = 0.3f))
			) {
				Row(
					modifier = Modifier.padding(16.dp),
					verticalAlignment = Alignment.CenterVertically,
					horizontalArrangement = Arrangement.Center
				) {
					Icon(
						imageVector = Icons.Default.CheckCircle,
						contentDescription = null,
						tint = Color(0xFF4CAF50),
						modifier = Modifier.size(24.dp)
					)
					Spacer(modifier = Modifier.width(12.dp))
					Text(
						text = signInSuccessMessage,
						style = MaterialTheme.typography.bodyLarge,
						fontWeight = FontWeight.Medium,
						color = MaterialTheme.colorScheme.onSurface
					)
				}
			}
		}
	}
}

@Composable
fun SignedInCard(
	user: PhotolalaUser,
	onSignOut: () -> Unit,
	onAccountSettings: () -> Unit = {}
) {
	Column(
		modifier = Modifier.fillMaxWidth(),
		horizontalAlignment = Alignment.CenterHorizontally
	) {
		// Profile Icon
		Icon(
			imageVector = Icons.Default.AccountCircle,
			contentDescription = null,
			modifier = Modifier.size(50.dp),
			tint = MaterialTheme.colorScheme.primary
		)
		
		Spacer(modifier = Modifier.height(16.dp))
		
		// User Information
		Column(
			horizontalAlignment = Alignment.CenterHorizontally
		) {
			Text(
				text = "Signed in as",
				style = MaterialTheme.typography.bodySmall,
				color = MaterialTheme.colorScheme.onSurfaceVariant
			)
			Spacer(modifier = Modifier.height(4.dp))
			Text(
				text = user.displayName,
				style = MaterialTheme.typography.headlineSmall,
				color = MaterialTheme.colorScheme.onSurface
			)
			user.email?.let { email ->
				Spacer(modifier = Modifier.height(4.dp))
				Text(
					text = email,
					style = MaterialTheme.typography.bodySmall,
					color = MaterialTheme.colorScheme.onSurfaceVariant
				)
			}
		}
		
		Spacer(modifier = Modifier.height(16.dp))
		
		// Action buttons
		Row(
			horizontalArrangement = Arrangement.spacedBy(16.dp)
		) {
			// Account Settings Button
			OutlinedButton(
				onClick = onAccountSettings,
				border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary)
			) {
				Text("Account Settings")
			}
			
			// Sign Out Button
			TextButton(
				onClick = onSignOut,
				colors = ButtonDefaults.textButtonColors(
					contentColor = MaterialTheme.colorScheme.error
				)
			) {
				Text("Sign Out")
			}
		}
	}
}

@Preview(showBackground = true)
@Composable
fun WelcomeScreenPreview() {
	PhotolalaTheme {
		WelcomeScreen()
	}
}