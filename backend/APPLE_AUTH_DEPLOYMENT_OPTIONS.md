# Apple Sign-In Backend Deployment Options for Photolala

Last Updated: January 3, 2025

## You DON'T Need EC2!

Here are better options for the Apple Sign-In token verification endpoint:

## Option 1: AWS Lambda (Recommended for Photolala)

Since you're already using AWS S3, Lambda is the natural choice:

```javascript
// lambda/appleAuth.js
exports.handler = async (event) => {
    const { id_token } = JSON.parse(event.body);
    
    // Verify token (same code as before)
    const user = await verifyAppleToken(id_token);
    
    // Create S3 identity mapping
    await s3.putObject({
        Bucket: 'photolala',
        Key: `identities/apple:${user.sub}`,
        Body: user.serviceUserId
    }).promise();
    
    return {
        statusCode: 200,
        headers: {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
            success: true, 
            user: user 
        })
    };
};
```

**Deploy with:**
```bash
# Using AWS CLI
aws lambda create-function \
  --function-name photolala-apple-auth \
  --runtime nodejs18.x \
  --handler appleAuth.handler \
  --zip-file fileb://lambda.zip

# Create API Gateway endpoint
aws apigatewayv2 create-api \
  --name photolala-auth \
  --protocol-type HTTP
```

**Costs:** 
- First 1M requests/month: FREE
- After that: $0.20 per 1M requests
- For Photolala: Probably $0-1/month

## Option 2: Firebase Functions

Even simpler if you want to avoid AWS complexity:

```javascript
// functions/index.js
const functions = require('firebase-functions');

exports.appleAuth = functions.https.onRequest(async (req, res) => {
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    
    const { id_token } = req.body;
    
    // Verify token
    const user = await verifyAppleToken(id_token);
    
    // You can still write to S3 from here
    await writeToS3(user);
    
    res.json({ success: true, user });
});
```

**Deploy with:**
```bash
firebase deploy --only functions
```

**Costs:**
- First 2M invocations/month: FREE
- After that: $0.40 per million
- For Photolala: FREE tier sufficient

## Option 3: Vercel Edge Functions

Super simple deployment:

```javascript
// api/apple-auth.js
export default async function handler(req, res) {
    const { id_token } = req.body;
    
    const user = await verifyAppleToken(id_token);
    await writeToS3(user);
    
    res.status(200).json({ success: true, user });
}
```

**Deploy with:**
```bash
vercel deploy
```

**Costs:**
- Hobby plan: FREE
- Pro plan: $20/month (if needed)

## Option 4: Cloudflare Workers

Fastest option (runs at edge):

```javascript
export default {
    async fetch(request) {
        const { id_token } = await request.json();
        
        const user = await verifyAppleToken(id_token);
        
        return new Response(JSON.stringify({ 
            success: true, 
            user 
        }), {
            headers: { 'Content-Type': 'application/json' }
        });
    }
};
```

**Costs:**
- First 100k requests/day: FREE
- Very cheap after that

## For Photolala, I Recommend: AWS Lambda

**Why?**
1. You're already using AWS (S3)
2. Direct VPC access to S3 if needed
3. Can use same AWS credentials
4. Integrates with your existing setup
5. Basically free for your usage

## Quick Lambda Setup for Photolala

1. **Create the function:**
```bash
# Create a new directory
mkdir photolala-auth-lambda
cd photolala-auth-lambda

# Copy the apple auth code
cp ../backend/apple-auth-example.js index.js

# Install dependencies
npm init -y
npm install jsonwebtoken jwks-rsa aws-sdk

# Create deployment package
zip -r lambda.zip .

# Deploy to AWS
aws lambda create-function \
  --function-name photolala-apple-auth \
  --runtime nodejs18.x \
  --role arn:aws:iam::YOUR_ACCOUNT:role/lambda-role \
  --handler index.handler \
  --zip-file fileb://lambda.zip
```

2. **Create API Gateway:**
```bash
# This gives you a public HTTPS endpoint
aws apigatewayv2 create-api \
  --name photolala-auth-api \
  --protocol-type HTTP \
  --target arn:aws:lambda:REGION:ACCOUNT:function:photolala-apple-auth
```

3. **Update Android code with endpoint:**
```kotlin
class AppleAuthService {
    companion object {
        // Your Lambda endpoint
        const val BACKEND_URL = "https://abc123.execute-api.us-east-1.amazonaws.com/apple-auth"
    }
    
    suspend fun verifyToken(idToken: String): PhotolalaUser {
        val response = httpClient.post(BACKEND_URL) {
            setBody(mapOf("id_token" to idToken))
        }
        return response.body()
    }
}
```

## Total Time to Deploy: 30 minutes

1. Copy the example code: 5 min
2. Deploy to Lambda: 10 min  
3. Create API Gateway: 5 min
4. Test endpoint: 5 min
5. Update Android app: 5 min

## No EC2 Needed!

EC2 would be overkill because:
- You need to manage the server
- Pay for idle time
- Handle scaling
- Security updates
- More complex

Serverless is perfect for this use case:
- Only runs when needed
- Automatically scales
- No maintenance
- Basically free
- More secure

## Environment Variables for Lambda

```bash
# Set your Apple Service ID
aws lambda update-function-configuration \
  --function-name photolala-apple-auth \
  --environment Variables="{APPLE_SERVICE_ID=com.electricwoods.photolala.service}"
```

## Monitoring

Lambda automatically provides:
- CloudWatch logs
- Error tracking  
- Performance metrics
- Alerts if needed

## Bottom Line

You can have Apple Sign-In working with:
- 30 minutes setup time
- $0-1/month in costs
- No server to manage
- Automatic scaling
- Same security as big apps

Just use Lambda! 🚀