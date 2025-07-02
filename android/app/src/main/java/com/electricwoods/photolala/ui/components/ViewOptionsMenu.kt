package com.electricwoods.photolala.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.AspectRatio
import androidx.compose.material.icons.filled.FitScreen
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun ViewOptionsMenu(
	currentScaleMode: String,
	onScaleModeChange: (String) -> Unit,
	modifier: Modifier = Modifier,
	additionalContent: @Composable ColumnScope.() -> Unit = {}
) {
	var expanded by remember { mutableStateOf(false) }
	
	Box(modifier = modifier) {
		IconButton(onClick = { expanded = true }) {
			Icon(
				imageVector = Icons.Default.MoreVert,
				contentDescription = "View Options"
			)
		}
		
		DropdownMenu(
			expanded = expanded,
			onDismissRequest = { expanded = false }
		) {
			// Scale mode section
			Text(
				text = "Image Scale",
				style = MaterialTheme.typography.labelMedium,
				modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
			)
			
			DropdownMenuItem(
				text = {
					Row(
						verticalAlignment = Alignment.CenterVertically,
						horizontalArrangement = Arrangement.spacedBy(12.dp)
					) {
						Icon(
							imageVector = Icons.Default.FitScreen,
							contentDescription = null,
							modifier = Modifier.size(20.dp)
						)
						Text("Scale to Fit")
					}
				},
				onClick = {
					onScaleModeChange("fit")
					expanded = false
				},
				leadingIcon = {
					RadioButton(
						selected = currentScaleMode == "fit",
						onClick = null
					)
				}
			)
			
			DropdownMenuItem(
				text = {
					Row(
						verticalAlignment = Alignment.CenterVertically,
						horizontalArrangement = Arrangement.spacedBy(12.dp)
					) {
						Icon(
							imageVector = Icons.Default.Fullscreen,
							contentDescription = null,
							modifier = Modifier.size(20.dp)
						)
						Text("Scale to Fill")
					}
				},
				onClick = {
					onScaleModeChange("fill")
					expanded = false
				},
				leadingIcon = {
					RadioButton(
						selected = currentScaleMode == "fill",
						onClick = null
					)
				}
			)
			
			// Additional content (for future thumbnail size options, etc.)
			additionalContent()
		}
	}
}