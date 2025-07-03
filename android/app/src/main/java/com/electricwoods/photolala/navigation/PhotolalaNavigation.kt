package com.electricwoods.photolala.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.electricwoods.photolala.ui.screens.AuthenticationScreen
import com.electricwoods.photolala.ui.screens.PhotoGridScreen
import com.electricwoods.photolala.ui.screens.PhotoViewerScreen
import com.electricwoods.photolala.ui.screens.WelcomeScreen
import com.electricwoods.photolala.ui.viewmodels.PhotoGridViewModel

@Composable
fun PhotolalaNavigation(
	navController: NavHostController = rememberNavController()
) {
	// Shared ViewModel for photo data
	val photoGridViewModel: PhotoGridViewModel = hiltViewModel()
	
	NavHost(
		navController = navController,
		startDestination = PhotolalaRoute.Welcome.route
	) {
		composable(PhotolalaRoute.Welcome.route) {
			WelcomeScreen(
				onBrowsePhotosClick = {
					navController.navigate(PhotolalaRoute.PhotoGrid.route)
				},
				onSignInClick = {
					navController.navigate(PhotolalaRoute.SignIn.route)
				},
				onCreateAccountClick = {
					navController.navigate(PhotolalaRoute.CreateAccount.route)
				}
			)
		}
		
		composable(PhotolalaRoute.PhotoGrid.route) {
			PhotoGridScreen(
				viewModel = photoGridViewModel,
				onPhotoClick = { photo, index ->
					navController.navigate(PhotolalaRoute.PhotoViewer.createRoute(index))
				}
			)
		}
		
		composable(
			route = PhotolalaRoute.PhotoViewer.route,
			arguments = listOf(
				navArgument("photoIndex") { type = NavType.IntType }
			)
		) { backStackEntry ->
			val photoIndex = backStackEntry.arguments?.getInt("photoIndex") ?: 0
			
			val viewerViewModel: com.electricwoods.photolala.ui.viewmodels.PhotoViewerViewModel = hiltViewModel()
			
			// Pass the photos from grid to viewer
			LaunchedEffect(Unit) {
				viewerViewModel.setPhotos(
					photoGridViewModel.photos.value,
					photoIndex
				)
			}
			
			PhotoViewerScreen(
				initialIndex = photoIndex,
				onBackClick = { navController.popBackStack() },
				viewModel = viewerViewModel
			)
		}
		
		composable(PhotolalaRoute.SignIn.route) {
			AuthenticationScreen(
				isSignUp = false,
				onAuthSuccess = {
					navController.popBackStack()
				},
				onCancel = {
					navController.popBackStack()
				}
			)
		}
		
		composable(PhotolalaRoute.CreateAccount.route) {
			AuthenticationScreen(
				isSignUp = true,
				onAuthSuccess = {
					navController.popBackStack()
				},
				onCancel = {
					navController.popBackStack()
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
	object SignIn : PhotolalaRoute("sign_in")
	object CreateAccount : PhotolalaRoute("create_account")
}