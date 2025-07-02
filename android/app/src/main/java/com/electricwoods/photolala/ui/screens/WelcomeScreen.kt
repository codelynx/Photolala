package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.electricwoods.photolala.R
import com.electricwoods.photolala.ui.theme.PhotolalaTheme

@Composable
fun WelcomeScreen(
	onBrowsePhotosClick: () -> Unit = {}
) {
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
		
		Spacer(modifier = Modifier.height(48.dp))
		
		// Browse button
		Button(
			onClick = onBrowsePhotosClick,
			modifier = Modifier.fillMaxWidth()
		) {
			Text("Browse Photos")
		}
		
		Spacer(modifier = Modifier.height(16.dp))
		
		// Future: Cloud browser button
		OutlinedButton(
			onClick = { /* TODO */ },
			modifier = Modifier.fillMaxWidth(),
			enabled = false
		) {
			Text("Cloud Browser (Coming Soon)")
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