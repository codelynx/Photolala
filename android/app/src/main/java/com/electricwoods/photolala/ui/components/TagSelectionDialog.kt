package com.electricwoods.photolala.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.electricwoods.photolala.models.ColorFlag

@Composable
fun TagSelectionDialog(
	currentTags: Set<ColorFlag>,
	onDismiss: () -> Unit,
	onToggleTag: (ColorFlag) -> Unit,
	onClearAll: () -> Unit
) {
	Dialog(onDismissRequest = onDismiss) {
		Card(
			modifier = Modifier
				.fillMaxWidth()
				.padding(16.dp),
			shape = RoundedCornerShape(16.dp),
			colors = CardDefaults.cardColors(
				containerColor = MaterialTheme.colorScheme.surface
			)
		) {
			Column(
				modifier = Modifier
					.fillMaxWidth()
					.padding(24.dp)
			) {
				// Title
				Row(
					modifier = Modifier.fillMaxWidth(),
					horizontalArrangement = Arrangement.SpaceBetween,
					verticalAlignment = Alignment.CenterVertically
				) {
					Column {
						Text(
							text = "Select Tags",
							style = MaterialTheme.typography.headlineSmall,
							fontWeight = FontWeight.Bold
						)
						Text(
							text = "Press 1-7 for quick selection",
							style = MaterialTheme.typography.bodySmall,
							color = MaterialTheme.colorScheme.onSurfaceVariant
						)
					}
					
					// Clear all button
					if (currentTags.isNotEmpty()) {
						TextButton(
							onClick = {
								onClearAll()
							}
						) {
							Icon(
								imageVector = Icons.Default.Clear,
								contentDescription = "Clear all",
								modifier = Modifier.size(16.dp)
							)
							Spacer(modifier = Modifier.width(4.dp))
							Text("Clear All")
						}
					}
				}
				
				Spacer(modifier = Modifier.height(24.dp))
				
				// Color flag grid - using weight to ensure equal sizes
				val colorFlags = (1..7).mapNotNull { ColorFlag.fromValue(it) }
				
				Column(
					verticalArrangement = Arrangement.spacedBy(12.dp),
					modifier = Modifier.fillMaxWidth()
				) {
					// First row: 1-4
					Row(
						modifier = Modifier.fillMaxWidth(),
						horizontalArrangement = Arrangement.spacedBy(8.dp)
					) {
						(0..3).forEach { index ->
							Box(
								modifier = Modifier
									.weight(1f)
									.aspectRatio(1f),
								contentAlignment = Alignment.Center
							) {
								if (index < colorFlags.size) {
									TagButton(
										colorFlag = colorFlags[index],
										isSelected = currentTags.contains(colorFlags[index]),
										onClick = { onToggleTag(colorFlags[index]) }
									)
								}
							}
						}
					}
					
					// Second row: 5-7 centered
					Row(
						modifier = Modifier.fillMaxWidth(),
						horizontalArrangement = Arrangement.spacedBy(8.dp)
					) {
						(0..3).forEach { index ->
							Box(
								modifier = Modifier
									.weight(1f)
									.aspectRatio(1f),
								contentAlignment = Alignment.Center
							) {
								when (index) {
									0 -> {} // Empty slot
									1, 2, 3 -> {
										val flagIndex = index + 3 // Maps to flags 5, 6, 7
										if (flagIndex < colorFlags.size) {
											TagButton(
												colorFlag = colorFlags[flagIndex],
												isSelected = currentTags.contains(colorFlags[flagIndex]),
												onClick = { onToggleTag(colorFlags[flagIndex]) }
											)
										}
									}
								}
							}
						}
					}
				}
				
				Spacer(modifier = Modifier.height(24.dp))
				
				// Action buttons
				Row(
					modifier = Modifier.fillMaxWidth(),
					horizontalArrangement = Arrangement.End
				) {
					TextButton(onClick = onDismiss) {
						Text("Done")
					}
				}
			}
		}
	}
}

@Composable
private fun TagButton(
	colorFlag: ColorFlag,
	isSelected: Boolean,
	onClick: () -> Unit
) {
	val color = when (colorFlag.value) {
		1 -> Color.Red
		2 -> Color(0xFFFFA500) // Orange
		3 -> Color.Yellow
		4 -> Color.Green
		5 -> Color.Blue
		6 -> Color(0xFF800080) // Purple
		7 -> Color.Gray
		else -> Color.Gray
	}
	
	Column(
		horizontalAlignment = Alignment.CenterHorizontally
	) {
		Box(
			modifier = Modifier
				.size(64.dp)
				.clip(CircleShape)
				.background(
					if (isSelected) {
						color.copy(alpha = 0.2f)
					} else {
						MaterialTheme.colorScheme.surfaceVariant
					}
				)
				.border(
					width = if (isSelected) 3.dp else 1.dp,
					color = if (isSelected) color else MaterialTheme.colorScheme.outline,
					shape = CircleShape
				)
				.clickable { onClick() },
			contentAlignment = Alignment.Center
		) {
			Icon(
				imageVector = Icons.Default.Flag,
				contentDescription = "Tag $colorFlag",
				modifier = Modifier.size(32.dp),
				tint = color
			)
			
			// Check mark overlay for selected state
			if (isSelected) {
				Box(
					modifier = Modifier
						.align(Alignment.BottomEnd)
						.size(20.dp)
						.background(color, CircleShape)
						.border(2.dp, MaterialTheme.colorScheme.surface, CircleShape),
					contentAlignment = Alignment.Center
				) {
					Icon(
						imageVector = Icons.Default.Check,
						contentDescription = "Selected",
						modifier = Modifier.size(12.dp),
						tint = Color.White
					)
				}
			}
		}
		
		Spacer(modifier = Modifier.height(4.dp))
		
		Text(
			text = colorFlag.value.toString(),
			style = MaterialTheme.typography.bodySmall,
			color = if (isSelected) color else MaterialTheme.colorScheme.onSurfaceVariant,
			fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
		)
	}
}