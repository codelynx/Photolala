plugins {
	alias(libs.plugins.android.application)
	alias(libs.plugins.kotlin.android)
	alias(libs.plugins.kotlin.compose)
	alias(libs.plugins.kotlin.serialization)
	alias(libs.plugins.hilt)
	alias(libs.plugins.ksp)
	// Google Services plugin (removed - not using Firebase)
	// alias(libs.plugins.google.services)
}

android {
	namespace = "com.electricwoods.photolala"
	compileSdk = 36

	buildFeatures {
		compose = true
	}
	composeOptions {
		kotlinCompilerExtensionVersion = "1.5.14"
	}

	defaultConfig {
		applicationId = "com.electricwoods.photolala"
		minSdk = 33
		targetSdk = 36
		versionCode = 1
		versionName = "1.0"

		testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
	}

	buildTypes {
		debug {
			// No suffix - using same package name for debug and release
			// applicationIdSuffix = ".debug"
			versionNameSuffix = "-DEBUG"
		}
		release {
			isMinifyEnabled = false
			proguardFiles(
				getDefaultProguardFile("proguard-android-optimize.txt"),
				"proguard-rules.pro"
			)
		}
	}
	compileOptions {
		sourceCompatibility = JavaVersion.VERSION_17
		targetCompatibility = JavaVersion.VERSION_17
	}
	kotlinOptions {
		jvmTarget = "17"
	}
	packaging {
		resources {
			excludes += "/META-INF/{AL2.0,LGPL2.1}"
			excludes += "/META-INF/DEPENDENCIES"
			excludes += "/META-INF/LICENSE"
			excludes += "/META-INF/LICENSE.txt"
			excludes += "/META-INF/license.txt"
			excludes += "/META-INF/NOTICE"
			excludes += "/META-INF/NOTICE.txt"
			excludes += "/META-INF/notice.txt"
			excludes += "/META-INF/ASL2.0"
			excludes += "/META-INF/INDEX.LIST"
			excludes += "/META-INF/*.kotlin_module"
		}
	}
}

dependencies {
	// Core Android
	implementation(libs.androidx.core.ktx)
	implementation(libs.androidx.activity.compose)
	implementation(libs.kotlinx.coroutines.android)
	implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
	
	// Compose
	implementation(platform(libs.androidx.compose.bom))
	implementation(libs.androidx.ui)
	implementation(libs.androidx.ui.graphics)
	implementation(libs.androidx.ui.tooling.preview)
	implementation(libs.androidx.material3)
	implementation(libs.androidx.material.icons.core)
	implementation(libs.androidx.material.icons.extended)
	
	// Navigation
	implementation(libs.androidx.navigation.compose)
	
	// Lifecycle
	implementation(libs.lifecycle.viewmodel.compose)
	implementation(libs.lifecycle.runtime.compose)
	
	// Hilt
	implementation(libs.hilt.android)
	ksp(libs.hilt.compiler)
	implementation(libs.hilt.navigation.compose)
	
	// Room
	implementation(libs.room.runtime)
	implementation(libs.room.ktx)
	ksp(libs.room.compiler)
	
	// Coil
	implementation(libs.coil.compose)
	
	// Zoomable for photo viewer
	implementation(libs.compose.zoomable)
	
	// DataStore
	implementation(libs.androidx.datastore.preferences)
	
	// WorkManager
	implementation(libs.androidx.work.runtime.ktx)
	
	// App Startup for initializers
	implementation("androidx.startup:startup-runtime:1.1.1")
	
	// AWS SDK
	implementation(libs.aws.android.sdk.s3)
	implementation(libs.aws.android.sdk.auth.userpools)
	
	// Serialization
	implementation(libs.kotlinx.serialization.json)
	
	// Google Sign-In
	// Note: Requires google-services.json from Firebase/Google Cloud Console
	// See GOOGLE_SIGNIN_SETUP.md for configuration instructions
	implementation(libs.play.services.auth)
	implementation(libs.androidx.credentials)
	implementation(libs.androidx.credentials.play.services.auth)
	implementation(libs.googleid)
	
	// Chrome Custom Tabs for Apple Sign-In
	implementation("androidx.browser:browser:1.7.0")
	
	// Accompanist permissions for runtime permission handling
	implementation("com.google.accompanist:accompanist-permissions:0.32.0")
	
	// Apple Sign-In dependencies
	implementation("com.squareup.okhttp3:okhttp:4.11.0")
	implementation("com.google.code.gson:gson:2.10.1")
	implementation("io.jsonwebtoken:jjwt-api:0.11.5")
	runtimeOnly("io.jsonwebtoken:jjwt-impl:0.11.5")
	runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.11.5")
	
	// Ktor HTTP client for Lambda calls
	implementation("io.ktor:ktor-client-core:2.3.7")
	implementation("io.ktor:ktor-client-cio:2.3.7")
	implementation("io.ktor:ktor-client-content-negotiation:2.3.7")
	implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.7")
	
	// Logging
	implementation("com.jakewharton.timber:timber:5.0.1")
	
	
	// Testing
	testImplementation(libs.junit)
	testImplementation("org.mockito:mockito-core:5.5.0")
	testImplementation("org.mockito:mockito-inline:5.2.0")
	androidTestImplementation(libs.androidx.junit)
	androidTestImplementation(libs.androidx.espresso.core)
	androidTestImplementation(platform(libs.androidx.compose.bom))
	androidTestImplementation(libs.androidx.ui.test.junit4)
	debugImplementation(libs.androidx.ui.tooling)
	debugImplementation(libs.androidx.ui.test.manifest)
}
