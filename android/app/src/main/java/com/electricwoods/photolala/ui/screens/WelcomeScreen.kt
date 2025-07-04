package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
	viewModel: WelcomeViewModel = hiltViewModel()
) {
	val currentUser by viewModel.currentUser.collectAsStateWithLifecycle()
	val isSignedIn by viewModel.isSignedIn.collectAsStateWithLifecycle()
	Column(
		modifier = Modifier
			.fillMaxSize()
			.padding(24.dp),
		verticalArrangement = Arrangement.Center,
		horizontalAlignment = Alignment.CenterHorizontally
	) {
		// App icon
		Image(
			painter = painterResource(id = R.drawable.ic_launcher_foreground),
			contentDescription = "Photolala",
			modifier = Modifier.size(120.dp)
		)
		
		Spacer(modifier = Modifier.height(24.dp))
		
		// Welcome text
		Text(
			text = "Welcome to Photolala",
			style = MaterialTheme.typography.headlineMedium,
			textAlign = TextAlign.Center
		)
		
		Spacer(modifier = Modifier.height(16.dp))
		
		Text(
			text = "Browse your photos with ease",
			style = MaterialTheme.typography.bodyLarge,
			textAlign = TextAlign.Center,
			color = MaterialTheme.colorScheme.onSurfaceVariant
		)
		
		// Show sign-in status if signed in
		if (isSignedIn && currentUser != null) {
			Spacer(modifier = Modifier.height(24.dp))
			SignedInCard(user = currentUser!!, onSignOut = viewModel::signOut)
		}
		
		Spacer(modifier = Modifier.height(48.dp))
		
		// Browse button
		Button(
			onClick = onBrowsePhotosClick,
			modifier = Modifier.fillMaxWidth()
		) {
			Text("Browse Photos")
		}
		
		Spacer(modifier = Modifier.height(16.dp))
		
		// Cloud browser button (enabled if signed in)
		OutlinedButton(
			onClick = onCloudBrowserClick,
			modifier = Modifier.fillMaxWidth(),
			enabled = isSignedIn
		) {
			Text(if (isSignedIn) "Cloud Browser" else "Cloud Browser (Sign In Required)")
		}
		
		// Sign in/Create account section
		if (!isSignedIn) {
			Spacer(modifier = Modifier.height(32.dp))
			
			Divider(
				modifier = Modifier.padding(horizontal = 32.dp),
				color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
			)
			
			Spacer(modifier = Modifier.height(24.dp))
			
			Text(
				text = "Backup and sync your photos",
				style = MaterialTheme.typography.bodyMedium,
				textAlign = TextAlign.Center,
				color = MaterialTheme.colorScheme.onSurfaceVariant
			)
			
			Spacer(modifier = Modifier.height(16.dp))
			
			// Sign In button
			Button(
				onClick = onSignInClick,
				modifier = Modifier.fillMaxWidth(),
				colors = ButtonDefaults.buttonColors(
					containerColor = MaterialTheme.colorScheme.primary
				)
			) {
				Text("Sign In")
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
}

@Composable
fun SignedInCard(
	user: PhotolalaUser,
	onSignOut: () -> Unit
) {
	Card(
		modifier = Modifier.fillMaxWidth(),
		colors = CardDefaults.cardColors(
			containerColor = MaterialTheme.colorScheme.secondaryContainer
		)
	) {
		Column(
			modifier = Modifier
				.fillMaxWidth()
				.padding(16.dp),
			horizontalAlignment = Alignment.CenterHorizontally
		) {
			Text(
				text = "Signed in as",
				fontSize = 14.sp,
				color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.7f)
			)
			Spacer(modifier = Modifier.height(4.dp))
			Text(
				text = user.displayName,
				fontSize = 16.sp,
				fontWeight = FontWeight.Medium,
				color = MaterialTheme.colorScheme.onSecondaryContainer
			)
			user.email?.let { email ->
				Text(
					text = email,
					fontSize = 14.sp,
					color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.7f)
				)
			}
			Spacer(modifier = Modifier.height(8.dp))
			TextButton(
				onClick = onSignOut
			) {
				Text(
					text = "Sign Out",
					color = MaterialTheme.colorScheme.error
				)
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