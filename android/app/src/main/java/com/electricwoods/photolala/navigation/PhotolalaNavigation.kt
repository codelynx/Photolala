package com.electricwoods.photolala.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.electricwoods.photolala.ui.screens.PhotoGridScreen
import com.electricwoods.photolala.ui.screens.WelcomeScreen

@Composable
fun PhotolalaNavigation(
	navController: NavHostController = rememberNavController()
) {
	NavHost(
		navController = navController,
		startDestination = PhotolalaRoute.Welcome.route
	) {
		composable(PhotolalaRoute.Welcome.route) {
			WelcomeScreen(
				onBrowsePhotosClick = {
					navController.navigate(PhotolalaRoute.PhotoGrid.route)
				}
			)
		}
		
		composable(PhotolalaRoute.PhotoGrid.route) {
			PhotoGridScreen(
				onPhotoClick = { photo, index ->
					// TODO: Navigate to photo viewer
					println("Photo clicked: ${photo.filename} at index $index")
				}
			)
		}
	}
}

sealed class PhotolalaRoute(val route: String) {
	object Welcome : PhotolalaRoute("welcome")
	object PhotoGrid : PhotolalaRoute("photo_grid")
	object PhotoViewer : PhotolalaRoute("photo_viewer/{photoIndex}") {
		fun createRoute(photoIndex: Int) = "photo_viewer/$photoIndex"
	}
}