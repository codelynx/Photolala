# Android Project Setup Guide

## Overview

This guide provides step-by-step instructions for setting up the Photolala Android project with modern Android development tools and architecture.

## Prerequisites

### Required Software
- **Android Studio**: Hedgehog (2023.1.1) or newer (Narwhal 2025.1.1 works great!)
- **JDK**: Version 17 (comes with Android Studio)
- **Git**: For version control
- **OS**: macOS, Windows, or Linux

### System Requirements
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 10GB free space
- **CPU**: Multi-core processor recommended

## Step 1: Create Android Project

### 1.1 Initialize Project in Android Studio

1. Open Android Studio
2. Click "New Project"
3. Select "Empty Activity" template
4. Configure project:
   ```
   Name: Photolala
   Package name: com.electricwoods.photolala
   Save location: /path/to/Photolala/android
   Language: Kotlin
   Minimum SDK: API 24 (Android 7.0)
   Build configuration language: Kotlin DSL
   ```
5. Click "Finish"

### 1.2 Clean Up Generated Files

Remove the default generated files:
```bash
cd android
rm -rf app/src/main/java/com/electricwoods/photolala/MainActivity.kt
rm -rf app/src/main/res/layout/
rm -rf app/src/androidTest/
rm -rf app/src/test/
```

## Step 2: Configure Project Structure

### 2.1 Create Module Structure

```bash
# From android directory
mkdir -p core/data/src/main/java/com/electricwoods/photolala/core/data
mkdir -p core/domain/src/main/java/com/electricwoods/photolala/core/domain
mkdir -p core/ui/src/main/java/com/electricwoods/photolala/core/ui
mkdir -p features/browser/src/main/java/com/electricwoods/photolala/features/browser
mkdir -p features/viewer/src/main/java/com/electricwoods/photolala/features/viewer
```

### 2.2 Update settings.gradle.kts

```kotlin
// android/settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Photolala"
include(":app")
include(":core:data")
include(":core:domain")
include(":core:ui")
include(":features:browser")
include(":features:viewer")
```

## Step 3: Configure Gradle

### 3.1 Create Version Catalog

Create `gradle/libs.versions.toml`:
```toml
[versions]
agp = "8.2.0"
kotlin = "1.9.20"
compose = "2024.02.00"
compose-compiler = "1.5.7"
hilt = "2.48"
room = "2.6.1"
coil = "2.5.0"
coroutines = "1.7.3"
lifecycle = "2.7.0"
navigation = "2.7.6"

[libraries]
# AndroidX
androidx-core = { module = "androidx.core:core-ktx", version = "1.12.0" }
androidx-lifecycle-runtime = { module = "androidx.lifecycle:lifecycle-runtime-ktx", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel = { module = "androidx.lifecycle:lifecycle-viewmodel-ktx", version.ref = "lifecycle" }
androidx-activity-compose = { module = "androidx.activity:activity-compose", version = "1.8.2" }

# Compose
compose-bom = { module = "androidx.compose:compose-bom", version.ref = "compose" }
compose-ui = { module = "androidx.compose.ui:ui" }
compose-ui-graphics = { module = "androidx.compose.ui:ui-graphics" }
compose-ui-tooling-preview = { module = "androidx.compose.ui:ui-tooling-preview" }
compose-material3 = { module = "androidx.compose.material3:material3" }
compose-ui-tooling = { module = "androidx.compose.ui:ui-tooling" }
compose-ui-test-manifest = { module = "androidx.compose.ui:ui-test-manifest" }

# Navigation
navigation-compose = { module = "androidx.navigation:navigation-compose", version.ref = "navigation" }

# Hilt
hilt-android = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler = { module = "com.google.dagger:hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { module = "androidx.hilt:hilt-navigation-compose", version = "1.1.0" }

# Room
room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
room-ktx = { module = "androidx.room:room-ktx", version.ref = "room" }
room-compiler = { module = "androidx.room:room-compiler", version.ref = "room" }

# Coil
coil-compose = { module = "io.coil-kt:coil-compose", version.ref = "coil" }

# Coroutines
kotlinx-coroutines-android = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-android", version.ref = "coroutines" }

# Testing
junit = { module = "junit:junit", version = "4.13.2" }
androidx-test-ext = { module = "androidx.test.ext:junit", version = "1.1.5" }
androidx-test-espresso = { module = "androidx.test.espresso:espresso-core", version = "3.5.1" }
compose-ui-test-junit4 = { module = "androidx.compose.ui:ui-test-junit4" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version = "1.9.20-1.0.14" }
```

### 3.2 Configure Root build.gradle.kts

```kotlin
// android/build.gradle.kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.ksp) apply false
}
```

### 3.3 Configure App Module

```kotlin
// android/app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.electricwoods.photolala"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.electricwoods.photolala"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
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

    buildFeatures {
        compose = true
        buildConfig = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation(project(":core:ui"))
    implementation(project(":core:domain"))
    implementation(project(":core:data"))
    implementation(project(":features:browser"))
    implementation(project(":features:viewer"))

    implementation(libs.androidx.core)
    implementation(libs.androidx.lifecycle.runtime)
    implementation(libs.androidx.activity.compose)
    
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    
    implementation(libs.navigation.compose)
    implementation(libs.hilt.android)
    implementation(libs.hilt.navigation.compose)
    ksp(libs.hilt.compiler)
    
    implementation(libs.coil.compose)
    implementation(libs.kotlinx.coroutines.android)

    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.ext)
    androidTestImplementation(libs.androidx.test.espresso)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
}
```

## Step 4: Create Core Modules

### 4.1 Core Domain Module

Create `core/domain/build.gradle.kts`:
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.electricwoods.photolala.core.domain"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
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
    implementation(libs.kotlinx.coroutines.android)
}
```

### 4.2 Core Data Module

Create `core/data/build.gradle.kts`:
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.electricwoods.photolala.core.data"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
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
    implementation(project(":core:domain"))
    
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    
    implementation(libs.kotlinx.coroutines.android)
}
```

### 4.3 Core UI Module

Create `core/ui/build.gradle.kts`:
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.electricwoods.photolala.core.ui"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
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
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    
    implementation(libs.coil.compose)
}
```

## Step 5: Create Feature Modules

### 5.1 Browser Feature Module

Create `features/browser/build.gradle.kts`:
```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.electricwoods.photolala.features.browser"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
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
    implementation(project(":core:ui"))
    implementation(project(":core:domain"))
    
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    
    implementation(libs.hilt.android)
    implementation(libs.hilt.navigation.compose)
    ksp(libs.hilt.compiler)
    
    implementation(libs.androidx.lifecycle.viewmodel)
    implementation(libs.navigation.compose)
}
```

## Step 6: Create Initial Source Files

### 6.1 Application Class

Create `app/src/main/java/com/electricwoods/photolala/PhotolalaApplication.kt`:
```kotlin
package com.electricwoods.photolala

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class PhotolalaApplication : Application()
```

### 6.2 MainActivity

Create `app/src/main/java/com/electricwoods/photolala/MainActivity.kt`:
```kotlin
package com.electricwoods.photolala

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.electricwoods.photolala.core.ui.theme.PhotolalaTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PhotolalaTheme {
                // Navigation will go here
            }
        }
    }
}
```

### 6.3 Theme

Create `core/ui/src/main/java/com/electricwoods/photolala/core/ui/theme/Theme.kt`:
```kotlin
package com.electricwoods.photolala.core.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

@Composable
fun PhotolalaTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> darkColorScheme()
        else -> lightColorScheme()
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
```

## Step 7: Configure AndroidManifest.xml

Update `app/src/main/AndroidManifest.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Permissions for MVP -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

    <application
        android:name=".PhotolalaApplication"
        android:allowBackup="true"
        android:dataExtractionRules="@xml/data_extraction_rules"
        android:fullBackupContent="@xml/backup_rules"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.Photolala"
        tools:targetApi="31">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.Photolala">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        
    </application>

</manifest>
```

## Step 8: Create Build Script

Create `android/build.sh`:
```bash
#!/bin/bash
# Build script for Photolala Android

set -e

echo "Building Photolala Android..."

# Clean
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Run unit tests
./gradlew test

echo "Build complete!"
echo "APK location: app/build/outputs/apk/debug/app-debug.apk"
```

Make it executable:
```bash
chmod +x android/build.sh
```

## Step 9: Verify Setup

### 9.1 Sync Project
1. Open the android folder in Android Studio
2. Click "Sync Project with Gradle Files"
3. Wait for sync to complete

### 9.2 Build Project
```bash
cd android
./gradlew build
```

### 9.3 Run on Emulator
1. Create an Android Virtual Device (AVD) in Android Studio
2. Run the app: `./gradlew installDebug`

## Step 10: Git Configuration

### 10.1 Update .gitignore

Add to root `.gitignore`:
```
# Android
android/.gradle/
android/build/
android/local.properties
android/captures/
android/.idea/
android/*.iml
android/app/build/
android/app/release/
android/app/debug/
android/core/*/build/
android/features/*/build/
```

## Next Steps

1. **Implement Domain Models**: Create Photo, Album, etc. in core:domain
2. **Set Up Navigation**: Implement navigation graph in app module
3. **Create Photo Grid**: Implement LazyVerticalGrid in browser feature
4. **Add MediaStore Access**: Implement in core:data
5. **Connect Everything**: Wire up with Hilt dependency injection

## Troubleshooting

### Common Issues

1. **Gradle Sync Failed**
   - Check internet connection
   - Invalidate caches: File → Invalidate Caches

2. **Build Failed**
   - Check JDK version (should be 17)
   - Clean project: `./gradlew clean`

3. **Permission Denied**
   - Ensure proper permissions in manifest
   - Request runtime permissions for Android 6.0+

This setup provides a solid foundation for building Photolala Android with modern architecture and tools.