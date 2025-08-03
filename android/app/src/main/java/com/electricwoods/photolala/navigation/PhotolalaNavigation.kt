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
import com.electricwoods.photolala.ui.screens.AccountSettingsScreen
import com.electricwoods.photolala.ui.screens.AuthenticationScreen
import com.electricwoods.photolala.ui.screens.CloudBrowserScreen
import com.electricwoods.photolala.ui.screens.PhotoGridScreen
import com.electricwoods.photolala.ui.screens.PhotoViewerScreen
import com.electricwoods.photolala.ui.screens.WelcomeScreen
import com.electricwoods.photolala.ui.viewmodels.AuthenticationViewModel
import com.electricwoods.photolala.ui.viewmodels.PhotoGridViewModel
import com.electricwoods.photolala.viewmodels.AccountSettingsViewModel
import androidx.compose.runtime.collectAsState

object PhotolalaNavigation {
	// Static reference to handle Google Sign-In result
	internal var pendingGoogleSignInHandler: ((Intent?) -> Unit)? = null
	
	// Track if we were in create account flow when Apple Sign-In was triggered
	internal var wasInCreateAccountFlow: Boolean = false
	
	// Track if we were in account linking flow
	internal var wasInAccountLinkingFlow: Boolean = false
	
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
				onCloudBrowserClick = {
					navController.navigate(PhotolalaRoute.CloudBrowser.route)
				},
				onSignInClick = {
					navController.navigate(PhotolalaRoute.SignIn.route)
				},
				onCreateAccountClick = {
					navController.navigate(PhotolalaRoute.CreateAccount.route)
				},
				onAccountSettingsClick = {
					navController.navigate(PhotolalaRoute.AccountSettings.route)
				}
			)
		}
		
		composable(PhotolalaRoute.PhotoGrid.route) {
			PhotoGridScreen(
				viewModel = photoGridViewModel,
				onPhotoClick = { photo, index ->
					navController.navigate(PhotolalaRoute.PhotoViewer.createRoute(index))
				},
				onBackClick = {
					navController.popBackStack()
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
					android.util.Log.d("PhotolalaNav", "=== SIGN-IN AUTH SUCCESS ===")
					android.util.Log.d("PhotolalaNav", "Clearing create account flow flag and navigating back")
					PhotolalaNavigation.wasInCreateAccountFlow = false
					navController.popBackStack()
					android.util.Log.d("PhotolalaNav", "Navigation completed")
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
					android.util.Log.d("PhotolalaNav", "=== CREATE ACCOUNT AUTH SUCCESS ===")
					android.util.Log.d("PhotolalaNav", "Clearing create account flow flag and navigating back")
					PhotolalaNavigation.wasInCreateAccountFlow = false
					navController.popBackStack()
					android.util.Log.d("PhotolalaNav", "Navigation completed")
				},
				onCancel = {
					navController.popBackStack()
				},
				viewModel = authViewModel
			)
		}
		
		composable(PhotolalaRoute.CloudBrowser.route) {
			CloudBrowserScreen(
				onPhotoClick = { photo, index ->
					// TODO: Navigate to photo viewer for S3 photos
					// For now, just go back
					navController.popBackStack()
				},
				onBackClick = {
					navController.popBackStack()
				}
			)
		}
		
		
		composable(PhotolalaRoute.AccountSettings.route) {
			val viewModel: AccountSettingsViewModel = hiltViewModel()
			val uiState by viewModel.uiState.collectAsState()
			
			// Handle Google Sign-In for linking
			LaunchedEffect(uiState.pendingLinkProvider) {
				if (uiState.pendingLinkProvider == com.electricwoods.photolala.models.AuthProvider.GOOGLE) {
					val intent = viewModel.getGoogleSignInIntent()
					if (intent != null) {
						PhotolalaNavigation.pendingGoogleSignInHandler = { data ->
							viewModel.handleGoogleSignInResult(data)
						}
						googleSignInLauncher.launch(intent)
					}
				} else if (uiState.pendingLinkProvider == com.electricwoods.photolala.models.AuthProvider.APPLE) {
					// Mark that we're in account linking flow
					PhotolalaNavigation.wasInAccountLinkingFlow = true
				}
			}
			
			AccountSettingsScreen(
				onNavigateBack = {
					navController.popBackStack()
				},
				viewModel = viewModel
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
	object CloudBrowser : PhotolalaRoute("cloud_browser")
	object AccountSettings : PhotolalaRoute("account_settings")
}