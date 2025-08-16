package com.electricwoods.photolala.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

/**
 * Navigation buttons for photo viewer with consistent styling
 */
@Composable
fun PhotoNavigationButtons(
	currentPage: Int,
	totalPages: Int,
	onPreviousClick: () -> Unit,
	onNextClick: () -> Unit,
	modifier: Modifier = Modifier
) {
	Row(
		modifier = modifier
			.fillMaxWidth()
			.padding(horizontal = 8.dp),
		horizontalArrangement = Arrangement.SpaceBetween
	) {
		// Previous button or spacer
		if (currentPage > 0) {
			NavigationButton(
				icon = Icons.Default.ChevronLeft,
				contentDescription = "Previous photo",
				onClick = onPreviousClick
			)
		} else {
			Spacer(modifier = Modifier.width(48.dp))
		}
		
		// Next button or spacer
		if (currentPage < totalPages - 1) {
			NavigationButton(
				icon = Icons.Default.ChevronRight,
				contentDescription = "Next photo",
				onClick = onNextClick
			)
		} else {
			Spacer(modifier = Modifier.width(48.dp))
		}
	}
}

@Composable
private fun NavigationButton(
	icon: ImageVector,
	contentDescription: String,
	onClick: () -> Unit,
	modifier: Modifier = Modifier
) {
	IconButton(
		onClick = onClick,
		modifier = modifier
			.size(48.dp)
			.background(
				Color.Black.copy(alpha = 0.5f),
				CircleShape
			)
	) {
		Icon(
			imageVector = icon,
			contentDescription = contentDescription,
			tint = Color.White,
			modifier = Modifier.size(32.dp)
		)
	}
}