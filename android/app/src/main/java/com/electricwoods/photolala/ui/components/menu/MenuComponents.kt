package com.electricwoods.photolala.ui.components.menu

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * A dropdown menu item with a radio button for single selection
 */
@Composable
fun RadioButtonMenuItem(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    DropdownMenuItem(
        text = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Start,
                verticalAlignment = Alignment.CenterVertically
            ) {
                RadioButton(
                    selected = selected,
                    onClick = null, // Handled by DropdownMenuItem
                    modifier = Modifier.padding(end = 8.dp)
                )
                Text(text)
            }
        },
        onClick = onClick,
        modifier = modifier,
        enabled = enabled
    )
}

/**
 * A dropdown menu item with a checkbox for toggles
 */
@Composable
fun CheckboxMenuItem(
    text: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    DropdownMenuItem(
        text = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Start,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Checkbox(
                    checked = checked,
                    onCheckedChange = null, // Handled by DropdownMenuItem
                    modifier = Modifier.padding(end = 8.dp)
                )
                Text(text)
            }
        },
        onClick = { onCheckedChange(!checked) },
        modifier = modifier,
        enabled = enabled
    )
}

/**
 * A section label for dropdown menus
 */
@Composable
fun DropdownMenuLabel(
    text: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

/**
 * A dropdown menu item that opens a nested submenu
 */
@Composable
fun NestedDropdownMenuItem(
    text: @Composable () -> Unit,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    children: @Composable ColumnScope.() -> Unit
) {
    Box {
        DropdownMenuItem(
            text = {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    text()
                    Icon(
                        imageVector = Icons.Default.ArrowRight,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                }
            },
            onClick = { onExpandedChange(true) },
            modifier = modifier,
            enabled = enabled
        )
        
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { onExpandedChange(false) }
        ) {
            children()
        }
    }
}

// Convenience function for simple text nested menus
@Composable
fun NestedDropdownMenuItem(
    text: String,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    children: @Composable ColumnScope.() -> Unit
) {
    NestedDropdownMenuItem(
        text = { Text(text) },
        expanded = expanded,
        onExpandedChange = onExpandedChange,
        modifier = modifier,
        enabled = enabled,
        children = children
    )
}