# Apple Sign-In Web Bridge for Android

## Problem

Apple Sign-In requires `response_mode=form_post` when requesting email/name scopes, which means Apple POSTs the response to a web URL, not directly to the Android app.

## Solution: Web-to-App Bridge

Create a simple web page at `https://photolala.eastlynx.com/auth/apple/callback` that receives the POST and redirects to the Android app.

### Example HTML Page

```html
<!DOCTYPE html>
<html>
<head>
    <title>Photolala - Signing in...</title>
    <script>
        // Extract form data from POST
        function handleAppleCallback() {
            const urlParams = new URLSearchParams();
            
            // Get all form inputs
            const formData = new FormData(document.getElementById('appleForm'));
            for (const [key, value] of formData) {
                urlParams.append(key, value);
            }
            
            // Redirect to Android app with parameters
            const appUrl = `photolala://auth/apple?${urlParams.toString()}`;
            window.location.href = appUrl;
            
            // Fallback for if app isn't installed
            setTimeout(() => {
                document.getElementById('status').textContent = 
                    'If the app did not open, please open Photolala manually.';
            }, 1000);
        }
        
        // Auto-submit if form data exists
        window.onload = function() {
            if (document.getElementById('code') || document.getElementById('id_token')) {
                handleAppleCallback();
            }
        };
    </script>
</head>
<body>
    <div style="text-align: center; padding: 50px; font-family: -apple-system, system-ui, sans-serif;">
        <h2>Signing in to Photolala...</h2>
        <p id="status">Redirecting to app...</p>
        
        <!-- Apple will POST to this form -->
        <form id="appleForm" method="post">
            <input type="hidden" name="state" id="state" value="">
            <input type="hidden" name="code" id="code" value="">
            <input type="hidden" name="id_token" id="id_token" value="">
            <input type="hidden" name="user" id="user" value="">
            <input type="hidden" name="error" id="error" value="">
        </form>
    </div>
</body>
</html>
```

### Server-Side Handler (PHP Example)

```php
<?php
// auth/apple/callback/index.php

// Get POST data
$state = $_POST['state'] ?? '';
$code = $_POST['code'] ?? '';
$id_token = $_POST['id_token'] ?? '';
$user = $_POST['user'] ?? '';
$error = $_POST['error'] ?? '';

// Build query string
$params = http_build_query([
    'state' => $state,
    'code' => $code,
    'id_token' => $id_token,
    'user' => $user,
    'error' => $error
]);

// Redirect to Android app
$appUrl = "photolala://auth/apple?" . $params;
header("Location: " . $appUrl);

// Also output HTML fallback
?>
<!DOCTYPE html>
<html>
<head>
    <title>Redirecting to Photolala...</title>
    <meta http-equiv="refresh" content="0; url=<?php echo htmlspecialchars($appUrl); ?>">
</head>
<body>
    <p>Redirecting to Photolala app...</p>
    <p>If the app doesn't open, <a href="<?php echo htmlspecialchars($appUrl); ?>">click here</a>.</p>
</body>
</html>
```

### Server-Side Handler (Node.js Example)

```javascript
// Using Express.js
app.post('/auth/apple/callback', (req, res) => {
    const { state, code, id_token, user, error } = req.body;
    
    // Build deep link URL
    const params = new URLSearchParams({
        state: state || '',
        code: code || '',
        id_token: id_token || '',
        user: user || '',
        error: error || ''
    });
    
    const appUrl = `photolala://auth/apple?${params.toString()}`;
    
    // Send HTML that redirects to app
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Redirecting to Photolala...</title>
            <script>
                window.location.href = "${appUrl}";
                setTimeout(() => {
                    document.getElementById('message').innerHTML = 
                        'If the app did not open, please open Photolala manually.';
                }, 1000);
            </script>
        </head>
        <body style="text-align: center; padding: 50px; font-family: -apple-system, system-ui, sans-serif;">
            <h2>Signing in to Photolala...</h2>
            <p id="message">Redirecting to app...</p>
        </body>
        </html>
    `);
});
```

## Update Android Manifest

Already configured correctly:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <data
        android:scheme="photolala"
        android:host="auth"
        android:pathPrefix="/apple" />
</intent-filter>
```

## Update MainActivity to Handle Deep Link

The MainActivity should extract query parameters and pass to AppleAuthService:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    handleIntent(intent)
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    handleIntent(intent)
}

private fun handleIntent(intent: Intent) {
    intent.data?.let { uri ->
        if (uri.scheme == "photolala" && uri.host == "auth" && uri.path?.startsWith("/apple") == true) {
            // Pass to AppleAuthService
            appleAuthService.handleCallback(uri)
        }
    }
}
```

## Testing

1. Deploy the web bridge to `https://photolala.eastlynx.com/auth/apple/callback`
2. Test Apple Sign-In flow
3. Verify the app receives the deep link with all parameters
4. Check that token exchange works with the authorization code