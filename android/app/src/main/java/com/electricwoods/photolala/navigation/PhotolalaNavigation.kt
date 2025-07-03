package com.electricwoods.photolala.navigation

import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.compose.runtime.*
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
import com.electricwoods.photolala.ui.viewmodels.AuthenticationViewModel
import com.electricwoods.photolala.ui.viewmodels.PhotoGridViewModel

object PhotolalaNavigation {
	// Static reference to handle Google Sign-In result
	internal var pendingGoogleSignInHandler: ((Intent?) -> Unit)? = null
	
	// Track if we were in create account flow when Apple Sign-In was triggered
	internal var wasInCreateAccountFlow: Boolean = false
	
	fun handleGoogleSignInResult(data: Intent?) {
		pendingGoogleSignInHandler?.invoke(data)
		pendingGoogleSignInHandler = null
	}
}

@Composable
fun PhotolalaNavigation(
	navController: NavHostController = rememberNavController(),
	googleSignInLauncher: ActivityResultLauncher<Intent>
) {
	// Shared ViewModel for photo data
	val photoGridViewModel: PhotoGridViewModel = hiltViewModel()
	
	NavHost(
		navController = navController,
		startDestination = PhotolalaRoute.Welcome.route
	) {
		composable(PhotolalaRoute.Welcome.route) {
			// Check if we need to restore navigation state after Apple Sign-In
			LaunchedEffect(Unit) {
				if (PhotolalaNavigation.wasInCreateAccountFlow) {
					// Reset the flag and navigate to create account
					PhotolalaNavigation.wasInCreateAccountFlow = false
					navController.navigate(PhotolalaRoute.CreateAccount.route)
				}
			}
			
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
			val authViewModel: AuthenticationViewModel = hiltViewModel()
			
			// Set up Google Sign-In callback
			LaunchedEffect(authViewModel) {
				authViewModel.onGoogleSignInRequired = { intent ->
					// Store the handler for when result comes back
					PhotolalaNavigation.pendingGoogleSignInHandler = { data ->
						authViewModel.handleGoogleSignInResult(data) {
							navController.popBackStack()
						}
					}
					googleSignInLauncher.launch(intent)
				}
				
				// Set up Apple Sign-In callback
				authViewModel.onAppleSignInRequired = {
					// Clear the create account flow flag
					PhotolalaNavigation.wasInCreateAccountFlow = false
					// Apple Sign-In will open in browser and return via deep link
					// The callback is handled in MainActivity
					// The browser is opened by AppleAuthService.signIn() which was already called
				}
			}
			
			AuthenticationScreen(
				isSignUp = false,
				onAuthSuccess = {
					PhotolalaNavigation.wasInCreateAccountFlow = false
					navController.popBackStack()
				},
				onCancel = {
					navController.popBackStack()
				},
				viewModel = authViewModel
			)
		}
		
		composable(PhotolalaRoute.CreateAccount.route) {
			val authViewModel: AuthenticationViewModel = hiltViewModel()
			
			// Set up Google Sign-In callback
			LaunchedEffect(authViewModel) {
				authViewModel.onGoogleSignInRequired = { intent ->
					// Store the handler for when result comes back
					PhotolalaNavigation.pendingGoogleSignInHandler = { data ->
						authViewModel.handleGoogleSignInResult(data) {
							navController.popBackStack()
						}
					}
					googleSignInLauncher.launch(intent)
				}
				
				// Set up Apple Sign-In callback
				authViewModel.onAppleSignInRequired = {
					// Mark that we're in create account flow
					PhotolalaNavigation.wasInCreateAccountFlow = true
					// Apple Sign-In will open in browser and return via deep link
					// The callback is handled in MainActivity
					// The browser is opened by AppleAuthService.signIn() which was already called
				}
			}
			
			AuthenticationScreen(
				isSignUp = true,
				onAuthSuccess = {
					PhotolalaNavigation.wasInCreateAccountFlow = false
					navController.popBackStack()
				},
				onCancel = {
					navController.popBackStack()
				},
				viewModel = authViewModel
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