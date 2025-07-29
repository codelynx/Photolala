# Domain Options for Apple Sign-In Callback

## Current Situation
- API Gateway URL: `https://kbzojywsa5.execute-api.us-east-1.amazonaws.com/prod/auth/apple/callback`
- Apple might not like the AWS subdomain format

## Options for Cleaner URLs

### Option 1: PHP Proxy on Your Existing Domain (Fastest)
1. Upload `simple-redirect.php` to your Hostmonster server at:
   ```
   /public_html/api/auth/apple/callback/index.php
   ```

2. Use this URL in Apple:
   ```
   https://photolala.electricwoods.com/api/auth/apple/callback
   ```

### Option 2: Netlify Subdomain (Free & Clean)
1. Create a free Netlify account
2. Deploy the `netlify-proxy` folder
3. Set custom domain: `auth-photolala.netlify.app`
4. Or add your own subdomain

### Option 3: CloudFront (Professional but takes time)
1. Run: `./create-cloudfront-domain.sh`
2. Wait 15-20 minutes for deployment
3. Use CloudFront URL or add CNAME

### Option 4: Direct API Gateway (What we have now)
Just use the current URL if Apple accepts it:
```
https://kbzojywsa5.execute-api.us-east-1.amazonaws.com/prod/auth/apple/callback
```

## Recommended: Try Option 4 First
The API Gateway URL might work fine. It's a standard HTTPS endpoint with:
- Valid SSL certificate
- Proper path structure (/prod/auth/apple/callback)
- Standard AWS domain format used by many apps

If Apple rejects it, then implement Option 1 (PHP proxy) as it's the quickest solution.