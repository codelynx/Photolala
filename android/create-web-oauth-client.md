# Create Web OAuth Client for Google Sign-In

Error code 10 occurs because we need a Web OAuth client ID for the ID token request.

## Steps:

1. Go to Google Cloud Console (signed in as kyoshikawa@electricwoods.com):
   ```
   https://console.cloud.google.com/apis/credentials?project=photolala-android
   ```

2. Click **"CREATE CREDENTIALS"** → **"OAuth client ID"**

3. Select **"Web application"** as Application type

4. Fill in:
   - **Name**: Photolala Web Client
   - **Authorized JavaScript origins**: (leave empty)
   - **Authorized redirect URIs**: (leave empty)

5. Click **"CREATE"**

6. Copy the **Client ID** from the popup (it will look like: xxxxx.apps.googleusercontent.com)

7. Update the code with the new Web Client ID

## Why is this needed?

Google Sign-In for Android requires:
- An Android OAuth client (for app verification) ✓ Already created
- A Web OAuth client (for ID token generation) ✗ Need to create

The Web client ID is used in `requestIdToken()` to get an ID token that can be verified on your backend.