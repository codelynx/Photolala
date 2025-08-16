package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.CardMembership
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.PhoneIphone
import androidx.compose.material.icons.filled.Language
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.models.PhotolalaUser
import com.electricwoods.photolala.models.ProviderLink
import com.electricwoods.photolala.models.SubscriptionTier
import com.electricwoods.photolala.ui.components.LockToPortraitEffect
import com.electricwoods.photolala.viewmodels.AccountSettingsViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSettingsScreen(
	onNavigateBack: () -> Unit,
	viewModel: AccountSettingsViewModel = hiltViewModel()
) {
	// Lock to portrait on smaller screens to prevent content clipping
	LockToPortraitEffect()
	
	val uiState by viewModel.uiState.collectAsState()
	val user = uiState.user
	
	var showUnlinkDialog by remember { mutableStateOf<AuthProvider?>(null) }
	var showLinkProviderDialog by remember { mutableStateOf(false) }
	
	Scaffold(
		topBar = {
			TopAppBar(
				title = { Text("Account Settings") },
				navigationIcon = {
					IconButton(onClick = onNavigateBack) {
						Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
					}
				}
			)
		}
	) { paddingValues ->
		if (user != null) {
			Column(
				modifier = Modifier
					.fillMaxSize()
					.padding(paddingValues)
					.verticalScroll(rememberScrollState())
			) {
				// User Header Card
				UserHeaderCard(user)
				
				// Storage Card
				StorageCard(user)
				
				// Subscription Card
				SubscriptionCard(user)
				
				// Sign-In Methods Card
				SignInMethodsCard(
					user = user,
					onLinkProvider = { showLinkProviderDialog = true },
					onUnlinkProvider = { provider -> showUnlinkDialog = provider }
				)
				
				// Spacer at bottom
				Spacer(modifier = Modifier.height(16.dp))
			}
		} else {
			// Loading or error state
			Box(
				modifier = Modifier
					.fillMaxSize()
					.padding(paddingValues),
				contentAlignment = Alignment.Center
			) {
				CircularProgressIndicator()
			}
		}
	}
	
	// Unlink Confirmation Dialog
	showUnlinkDialog?.let { provider ->
		AlertDialog(
			onDismissRequest = { showUnlinkDialog = null },
			title = { Text("Unlink ${provider.displayName}?") },
			text = {
				Text(
					"You'll no longer be able to sign in with your ${provider.displayName} account. " +
					"You can always link it again later."
				)
			},
			confirmButton = {
				TextButton(
					onClick = {
						viewModel.unlinkProvider(provider)
						showUnlinkDialog = null
					}
				) {
					Text("Unlink", color = MaterialTheme.colorScheme.error)
				}
			},
			dismissButton = {
				TextButton(onClick = { showUnlinkDialog = null }) {
					Text("Cancel")
				}
			}
		)
	}
	
	// Link Provider Dialog
	if (showLinkProviderDialog) {
		LinkProviderDialog(
			currentProviders = getAllProviders(user!!),
			onProviderSelected = { provider ->
				viewModel.linkProvider(provider)
				showLinkProviderDialog = false
			},
			onDismiss = { showLinkProviderDialog = false }
		)
	}
	
	// Error messages
	uiState.errorMessage?.let { error ->
		AlertDialog(
			onDismissRequest = { viewModel.clearError() },
			title = { Text("Error") },
			text = { Text(error) },
			confirmButton = {
				TextButton(onClick = { viewModel.clearError() }) {
					Text("OK")
				}
			}
		)
	}
}

@Composable
private fun UserHeaderCard(user: PhotolalaUser) {
	Card(
		modifier = Modifier
			.fillMaxWidth()
			.padding(16.dp),
		shape = RoundedCornerShape(16.dp),
		elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
	) {
		Box(
			modifier = Modifier
				.fillMaxWidth()
				.background(
					Brush.verticalGradient(
						colors = listOf(
							MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
							MaterialTheme.colorScheme.primary.copy(alpha = 0.05f)
						)
					)
				)
				.padding(24.dp)
		) {
			Column(
				horizontalAlignment = Alignment.CenterHorizontally,
				modifier = Modifier.fillMaxWidth()
			) {
				// Avatar
				Box(
					modifier = Modifier
						.size(80.dp)
						.clip(CircleShape)
						.background(MaterialTheme.colorScheme.primary),
					contentAlignment = Alignment.Center
				) {
					Icon(
						Icons.Filled.Person,
						contentDescription = null,
						modifier = Modifier.size(48.dp),
						tint = MaterialTheme.colorScheme.onPrimary
					)
				}
				
				Spacer(modifier = Modifier.height(16.dp))
				
				// Name
				Text(
					text = user.displayName,
					style = MaterialTheme.typography.headlineSmall,
					fontWeight = FontWeight.Bold
				)
				
				// Email
				user.email?.let { email ->
					Text(
						text = email,
						style = MaterialTheme.typography.bodyMedium,
						color = MaterialTheme.colorScheme.onSurfaceVariant
					)
				}
				
				// User ID
				Text(
					text = "ID: ${user.serviceUserID.take(8)}...",
					style = MaterialTheme.typography.bodySmall,
					color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
				)
			}
		}
	}
}

@Composable
private fun StorageCard(user: PhotolalaUser) {
	Card(
		modifier = Modifier
			.fillMaxWidth()
			.padding(horizontal = 16.dp, vertical = 8.dp),
		shape = RoundedCornerShape(16.dp),
		elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
	) {
		Column(
			modifier = Modifier.padding(20.dp)
		) {
			Row(
				modifier = Modifier.fillMaxWidth(),
				horizontalArrangement = Arrangement.SpaceBetween,
				verticalAlignment = Alignment.CenterVertically
			) {
				Row(verticalAlignment = Alignment.CenterVertically) {
					Icon(
						Icons.Filled.Storage,
						contentDescription = null,
						tint = MaterialTheme.colorScheme.primary
					)
					Spacer(modifier = Modifier.width(12.dp))
					Text(
						text = "Storage",
						style = MaterialTheme.typography.titleMedium,
						fontWeight = FontWeight.SemiBold
					)
				}
			}
			
			Spacer(modifier = Modifier.height(16.dp))
			
			// Storage progress bar (placeholder - would need actual usage data)
			LinearProgressIndicator(
				progress = 0.3f,
				modifier = Modifier
					.fillMaxWidth()
					.height(8.dp)
					.clip(RoundedCornerShape(4.dp))
			)
			
			Spacer(modifier = Modifier.height(8.dp))
			
			Row(
				modifier = Modifier.fillMaxWidth(),
				horizontalArrangement = Arrangement.SpaceBetween
			) {
				Text(
					text = "1.5 GB used",
					style = MaterialTheme.typography.bodySmall,
					color = MaterialTheme.colorScheme.onSurfaceVariant
				)
				Text(
					text = formatStorageLimit(user.subscription?.tier?.storageLimit ?: 0),
					style = MaterialTheme.typography.bodySmall,
					color = MaterialTheme.colorScheme.onSurfaceVariant
				)
			}
		}
	}
}

@Composable
private fun SubscriptionCard(user: PhotolalaUser) {
	val subscription = user.subscription
	
	Card(
		modifier = Modifier
			.fillMaxWidth()
			.padding(horizontal = 16.dp, vertical = 8.dp),
		shape = RoundedCornerShape(16.dp),
		elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
	) {
		Column(
			modifier = Modifier.padding(20.dp)
		) {
			Row(
				modifier = Modifier.fillMaxWidth(),
				horizontalArrangement = Arrangement.SpaceBetween,
				verticalAlignment = Alignment.CenterVertically
			) {
				Row(verticalAlignment = Alignment.CenterVertically) {
					Icon(
						Icons.Filled.CardMembership,
						contentDescription = null,
						tint = MaterialTheme.colorScheme.primary
					)
					Spacer(modifier = Modifier.width(12.dp))
					Text(
						text = "Subscription",
						style = MaterialTheme.typography.titleMedium,
						fontWeight = FontWeight.SemiBold
					)
				}
				
				if (subscription != null) {
					Surface(
						shape = RoundedCornerShape(8.dp),
						color = when (subscription.tier) {
							SubscriptionTier.PRO, SubscriptionTier.BUSINESS -> 
								MaterialTheme.colorScheme.primary
							else -> MaterialTheme.colorScheme.surfaceVariant
						}
					) {
						Text(
							text = subscription.tier.displayName,
							style = MaterialTheme.typography.labelMedium,
							modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
						)
					}
				}
			}
			
			if (subscription != null) {
				Spacer(modifier = Modifier.height(12.dp))
				
				Row(
					modifier = Modifier.fillMaxWidth(),
					horizontalArrangement = Arrangement.SpaceBetween
				) {
					Text(
						text = "Status",
						style = MaterialTheme.typography.bodyMedium,
						color = MaterialTheme.colorScheme.onSurfaceVariant
					)
					Text(
						text = subscription.status.name.lowercase()
							.replaceFirstChar { it.titlecase() },
						style = MaterialTheme.typography.bodyMedium,
						fontWeight = FontWeight.Medium,
						color = if (subscription.status.name == "ACTIVE") 
							MaterialTheme.colorScheme.primary 
						else 
							MaterialTheme.colorScheme.error
					)
				}
			}
		}
	}
}

@Composable
private fun SignInMethodsCard(
	user: PhotolalaUser,
	onLinkProvider: () -> Unit,
	onUnlinkProvider: (AuthProvider) -> Unit
) {
	Card(
		modifier = Modifier
			.fillMaxWidth()
			.padding(horizontal = 16.dp, vertical = 8.dp),
		shape = RoundedCornerShape(16.dp),
		elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
	) {
		Column(
			modifier = Modifier.padding(20.dp)
		) {
			Row(verticalAlignment = Alignment.CenterVertically) {
				Icon(
					Icons.Filled.Security,
					contentDescription = null,
					tint = MaterialTheme.colorScheme.primary
				)
				Spacer(modifier = Modifier.width(12.dp))
				Text(
					text = "Sign-In Methods",
					style = MaterialTheme.typography.titleMedium,
					fontWeight = FontWeight.SemiBold
				)
			}
			
			Spacer(modifier = Modifier.height(16.dp))
			
			// Primary provider
			ProviderRow(
				provider = user.primaryProvider,
				isPrimary = true,
				linkedDate = user.createdAt,
				onUnlink = null // Cannot unlink primary if it's the only one
			)
			
			// Linked providers
			user.linkedProviders.forEach { link ->
				Spacer(modifier = Modifier.height(8.dp))
				ProviderRow(
					provider = link.provider,
					isPrimary = false,
					linkedDate = link.linkedAt,
					onUnlink = { onUnlinkProvider(link.provider) }
				)
			}
			
			// Link another provider button
			Spacer(modifier = Modifier.height(16.dp))
			
			Button(
				onClick = onLinkProvider,
				modifier = Modifier.fillMaxWidth(),
				shape = RoundedCornerShape(12.dp)
			) {
				Icon(
					Icons.Filled.Add,
					contentDescription = null,
					modifier = Modifier.size(20.dp)
				)
				Spacer(modifier = Modifier.width(8.dp))
				Text("Link Another Sign-In Method")
			}
		}
	}
}

@Composable
private fun ProviderRow(
	provider: AuthProvider,
	isPrimary: Boolean,
	linkedDate: Date,
	onUnlink: (() -> Unit)?
) {
	val dateFormat = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
	
	Row(
		modifier = Modifier
			.fillMaxWidth()
			.clip(RoundedCornerShape(8.dp))
			.background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
			.padding(12.dp),
		horizontalArrangement = Arrangement.SpaceBetween,
		verticalAlignment = Alignment.CenterVertically
	) {
		Row(
			verticalAlignment = Alignment.CenterVertically,
			modifier = Modifier.weight(1f)
		) {
			Icon(
				imageVector = when (provider) {
					AuthProvider.APPLE -> Icons.Filled.PhoneIphone
					AuthProvider.GOOGLE -> Icons.Filled.Language
				},
				contentDescription = null,
				tint = MaterialTheme.colorScheme.onSurfaceVariant
			)
			
			Spacer(modifier = Modifier.width(12.dp))
			
			Column {
				Row(verticalAlignment = Alignment.CenterVertically) {
					Text(
						text = provider.displayName,
						style = MaterialTheme.typography.bodyLarge,
						fontWeight = FontWeight.Medium
					)
					if (isPrimary) {
						Spacer(modifier = Modifier.width(8.dp))
						Text(
							text = "Primary",
							style = MaterialTheme.typography.labelSmall,
							color = MaterialTheme.colorScheme.primary,
							modifier = Modifier
								.background(
									MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
									RoundedCornerShape(4.dp)
								)
								.padding(horizontal = 6.dp, vertical = 2.dp)
						)
					}
				}
				Text(
					text = "Linked on ${dateFormat.format(linkedDate)}",
					style = MaterialTheme.typography.bodySmall,
					color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
				)
			}
		}
		
		// Only show unlink button if it's not the only provider
		if (onUnlink != null) {
			TextButton(
				onClick = onUnlink,
				colors = ButtonDefaults.textButtonColors(
					contentColor = MaterialTheme.colorScheme.error
				)
			) {
				Text("Unlink")
			}
		}
	}
}

@Composable
private fun LinkProviderDialog(
	currentProviders: Set<AuthProvider>,
	onProviderSelected: (AuthProvider) -> Unit,
	onDismiss: () -> Unit
) {
	val availableProviders = AuthProvider.values().filter { it !in currentProviders }
	
	AlertDialog(
		onDismissRequest = onDismiss,
		title = { Text("Link Sign-In Method") },
		text = {
			if (availableProviders.isEmpty()) {
				Text("All available sign-in methods are already linked.")
			} else {
				Column {
					Text("Select a sign-in method to link:")
					Spacer(modifier = Modifier.height(16.dp))
					availableProviders.forEach { provider ->
						OutlinedCard(
							onClick = { onProviderSelected(provider) },
							modifier = Modifier
								.fillMaxWidth()
								.padding(vertical = 4.dp)
						) {
							Row(
								modifier = Modifier
									.fillMaxWidth()
									.padding(16.dp),
								verticalAlignment = Alignment.CenterVertically
							) {
								Icon(
									imageVector = when (provider) {
										AuthProvider.APPLE -> Icons.Filled.PhoneIphone
										AuthProvider.GOOGLE -> Icons.Filled.Language
									},
									contentDescription = null
								)
								Spacer(modifier = Modifier.width(12.dp))
								Text(provider.displayName)
							}
						}
					}
				}
			}
		},
		confirmButton = {
			if (availableProviders.isEmpty()) {
				TextButton(onClick = onDismiss) {
					Text("OK")
				}
			}
		},
		dismissButton = {
			if (availableProviders.isNotEmpty()) {
				TextButton(onClick = onDismiss) {
					Text("Cancel")
				}
			}
		}
	)
}

private fun getAllProviders(user: PhotolalaUser): Set<AuthProvider> {
	return setOf(user.primaryProvider) + user.linkedProviders.map { it.provider }.toSet()
}

private fun formatStorageLimit(bytes: Long): String {
	return when {
		bytes >= 1_000_000_000_000L -> "${bytes / 1_000_000_000_000} TB"
		bytes >= 1_000_000_000L -> "${bytes / 1_000_000_000} GB"
		else -> "${bytes / 1_000_000} MB"
	}
}