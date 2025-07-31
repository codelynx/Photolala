# TODO: Recreate Photolala Project

## Task
Recreate the "photolala" Google Cloud project under electricwoods.com account

## When
Check after 1 hour from deletion (deleted around your current time)

## Steps
1. Run: `gcloud config set account kyoshikawa@electricwoods.com`
2. Run: `gcloud projects create photolala --name="Photolala"`
3. Set up in Google Cloud Console:
   - Enable Photos Library API
   - Configure OAuth consent screen
   - Add test users
   - Create Android OAuth client with SHA-1: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`
4. Download new google-services.json
5. Replace in android/app/

## Alternative
If "photolala" still not available, create as "photolala-android" or "photolala-prod"