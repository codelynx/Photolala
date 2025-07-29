# Apple Sign-In Troubleshooting

## Error: "Invalid web redirect url"

This error typically means one of the following:

### 1. Service ID Configuration Issues
- Make sure you're using a **Service ID**, not an App ID
- The Service ID identifier should be: `com.electricwoods.photolala.android`
- The Service ID must be configured for "Sign in with Apple"

### 2. Redirect URL Configuration
In Apple Developer Portal, for your Service ID:
1. Go to Certificates, Identifiers & Profiles
2. Select Identifiers → Service IDs
3. Click on your Service ID (com.electricwoods.photolala.android)
4. Click "Configure" next to "Sign in with Apple"
5. Add the website domain: `photolala.eastlynx.com`
6. Add the Return URL: `https://photolala.eastlynx.com/auth/apple/callback`

### 3. Common Issues and Solutions

**Issue**: Apple requires exact URL match
- Make sure there's no trailing slash
- URL must be HTTPS
- Domain must be verified

**Issue**: Domain verification
- Apple might require domain verification
- Add the apple-developer-domain-association file if needed

**Issue**: Service ID not properly configured
- Service ID must be different from App ID
- Must be explicitly enabled for "Sign in with Apple"

### 4. Test URLs
Try these URLs in order:

1. Clean subdomain:
   ```
   https://photolala.eastlynx.com/auth/apple/callback
   ```

2. If that fails, try the direct Lambda URL:
   ```
   https://xrfhu5bmphta4qcthdb46siviu0wmmty.lambda-url.us-east-1.on.aws/
   ```

3. Or API Gateway URL:
   ```
   https://kbzojywsa5.execute-api.us-east-1.amazonaws.com/prod/auth/apple/callback
   ```

### 5. Verification Steps
1. Open `test-apple-url.html` in a browser
2. Try each URL option
3. See which one Apple accepts
4. Update the Service ID configuration accordingly