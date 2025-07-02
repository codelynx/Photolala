package com.electricwoods.photolala.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.electricwoods.photolala.utils.DeviceUtils

@Composable
fun GridViewOptionsMenu(
	currentThumbnailSize: Int,
	currentScaleMode: String,
	onThumbnailSizeChange: (Int) -> Unit,
	onScaleModeChange: (String) -> Unit,
	modifier: Modifier = Modifier
) {
	var expanded by remember { mutableStateOf(false) }
	
	Box(modifier = modifier) {
		IconButton(onClick = { expanded = true }) {
			Icon(
				imageVector = Icons.Default.Tune,
				contentDescription = "View Options"
			)
		}
		
		DropdownMenu(
			expanded = expanded,
			onDismissRequest = { expanded = false }
		) {
			// Thumbnail size section
			Text(
				text = "Thumbnail Size",
				style = MaterialTheme.typography.labelMedium,
				modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
			)
			
			val context = LocalContext.current
			val thumbnailSizes = DeviceUtils.getRecommendedThumbnailSizes(context)
			
			thumbnailSizes.forEach { (size, label) ->
				DropdownMenuItem(
					text = { Text(label) },
					onClick = {
						onThumbnailSizeChange(size)
						expanded = false
					},
					leadingIcon = {
						RadioButton(
							selected = currentThumbnailSize == size,
							onClick = null
						)
					}
				)
			}
			
			Divider(modifier = Modifier.padding(vertical = 8.dp))
			
			// Scale mode section
			Text(
				text = "Scale Mode",
				style = MaterialTheme.typography.labelMedium,
				modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
			)
			
			val scaleModes = listOf(
				"fit" to "Scale to Fit",
				"fill" to "Scale to Fill"
			)
			
			scaleModes.forEach { (mode, label) ->
				DropdownMenuItem(
					text = { Text(label) },
					onClick = {
						onScaleModeChange(mode)
						expanded = false
					},
					leadingIcon = {
						RadioButton(
							selected = currentScaleMode == mode,
							onClick = null
						)
					}
				)
			}
		}
	}
}