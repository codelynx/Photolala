plugins {
	alias(libs.plugins.android.application)
	alias(libs.plugins.kotlin.android)
	alias(libs.plugins.kotlin.compose)
	alias(libs.plugins.hilt)
	alias(libs.plugins.ksp)
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
}

dependencies {
	// Core Android
	implementation(libs.androidx.core.ktx)
	implementation(libs.androidx.activity.compose)
	implementation(libs.kotlinx.coroutines.android)
	
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
	
	// AWS SDK
	implementation(libs.aws.android.sdk.s3)
	implementation(libs.aws.android.sdk.auth.userpools)
	
	// Testing
	testImplementation(libs.junit)
	androidTestImplementation(libs.androidx.junit)
	androidTestImplementation(libs.androidx.espresso.core)
	androidTestImplementation(platform(libs.androidx.compose.bom))
	androidTestImplementation(libs.androidx.ui.test.junit4)
	debugImplementation(libs.androidx.ui.tooling)
	debugImplementation(libs.androidx.ui.test.manifest)
}
