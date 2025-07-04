package com.electricwoods.photolala.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.electricwoods.photolala.services.BackupQueueManager

@Composable
fun BackupStatusIndicator(
	backupQueueManager: BackupQueueManager,
	modifier: Modifier = Modifier
) {
	val isUploading by backupQueueManager.isUploading.collectAsState()
	val uploadProgress by backupQueueManager.uploadProgress.collectAsState()
	val currentUploadingPhoto by backupQueueManager.currentUploadingPhoto.collectAsState()
	val uploadedCount by backupQueueManager.uploadedCount.collectAsState()
	
	AnimatedVisibility(
		visible = isUploading,
		enter = fadeIn(),
		exit = fadeOut(),
		modifier = modifier
	) {
		Card(
			modifier = Modifier
				.fillMaxWidth()
				.padding(horizontal = 16.dp, vertical = 8.dp),
			shape = RoundedCornerShape(8.dp),
			colors = CardDefaults.cardColors(
				containerColor = MaterialTheme.colorScheme.surfaceVariant
			)
		) {
			Column(
				modifier = Modifier
					.fillMaxWidth()
					.padding(16.dp)
			) {
				Row(
					modifier = Modifier.fillMaxWidth(),
					horizontalArrangement = Arrangement.SpaceBetween,
					verticalAlignment = Alignment.CenterVertically
				) {
					Column(modifier = Modifier.weight(1f)) {
						Text(
							text = "Backing up photos",
							style = MaterialTheme.typography.bodyMedium,
							fontSize = 14.sp
						)
						
						currentUploadingPhoto?.let { filename ->
							Text(
								text = filename,
								style = MaterialTheme.typography.bodySmall,
								color = MaterialTheme.colorScheme.onSurfaceVariant,
								fontSize = 12.sp,
								maxLines = 1,
								overflow = TextOverflow.Ellipsis
							)
						}
					}
					
					Text(
						text = "$uploadedCount uploaded",
						style = MaterialTheme.typography.bodySmall,
						color = MaterialTheme.colorScheme.primary,
						fontSize = 12.sp
					)
				}
				
				Spacer(modifier = Modifier.height(8.dp))
				
				LinearProgressIndicator(
					progress = { uploadProgress },
					modifier = Modifier.fillMaxWidth(),
					color = MaterialTheme.colorScheme.primary,
					trackColor = MaterialTheme.colorScheme.surfaceVariant,
				)
			}
		}
	}
}

@Composable
fun BackupStatusBadge(
	backupQueueManager: BackupQueueManager,
	modifier: Modifier = Modifier,
	onClick: () -> Unit = {}
) {
	val isUploading by backupQueueManager.isUploading.collectAsState()
	val uploadedCount by backupQueueManager.uploadedCount.collectAsState()
	
	if (isUploading) {
		Badge(
			modifier = modifier,
			containerColor = MaterialTheme.colorScheme.primary
		) {
			Text(
				text = "$uploadedCount",
				fontSize = 10.sp
			)
		}
	}
}