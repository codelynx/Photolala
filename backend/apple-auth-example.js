/**
 * Example backend implementation for Sign in with Apple
 * This would typically be deployed as a Firebase Function, AWS Lambda, or Express server
 * 
 * For Photolala, this handles the secure token verification that shouldn't be done client-side
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const AWS = require('aws-sdk');

// Initialize AWS S3 for identity persistence
const s3 = new AWS.S3();
const BUCKET_NAME = 'photolala';

// Apple's public key client for token verification
const appleKeysClient = jwksClient({
    jwksUri: 'https://appleid.apple.com/auth/keys',
    cache: true,
    rateLimit: true
});

/**
 * Main endpoint for Apple Sign In
 * POST /auth/apple
 * Body: { id_token, authorization_code }
 */
async function handleAppleSignIn(req, res) {
    try {
        const { id_token, authorization_code } = req.body;
        
        if (!id_token) {
            return res.status(400).json({ 
                error: 'Missing id_token' 
            });
        }
        
        // 1. Verify the ID token from Apple
        const appleUser = await verifyAppleIdToken(id_token);
        
        // 2. Check if user exists in S3
        const existingUser = await checkExistingUser(appleUser.sub);
        
        let photolalaUser;
        if (existingUser) {
            // 3a. Existing user - sign in
            photolalaUser = existingUser;
            console.log(`User signed in: apple:${appleUser.sub}`);
        } else {
            // 3b. New user - create account
            photolalaUser = await createNewUser(appleUser);
            console.log(`New user created: apple:${appleUser.sub}`);
        }
        
        // 4. Generate app token (you'd implement your own JWT here)
        const appToken = generateAppToken(photolalaUser);
        
        // 5. Return success response
        res.json({
            success: true,
            user: photolalaUser,
            token: appToken
        });
        
    } catch (error) {
        console.error('Apple sign in error:', error);
        res.status(401).json({ 
            error: error.message || 'Authentication failed' 
        });
    }
}

/**
 * Verify Apple's ID token using their public keys
 */
async function verifyAppleIdToken(idToken) {
    // Decode token header to get key ID
    const decoded = jwt.decode(idToken, { complete: true });
    if (!decoded) {
        throw new Error('Invalid token format');
    }
    
    const { kid } = decoded.header;
    
    // Get Apple's public key
    const key = await appleKeysClient.getSigningKey(kid);
    const publicKey = key.getPublicKey();
    
    // Verify token signature and claims
    const verified = jwt.verify(idToken, publicKey, {
        issuer: 'https://appleid.apple.com',
        audience: 'com.electricwoods.photolala.service', // Your Service ID
        algorithms: ['RS256']
    });
    
    // Validate required claims
    if (!verified.sub) {
        throw new Error('Token missing user ID');
    }
    
    return {
        sub: verified.sub,           // Apple user ID
        email: verified.email,       // May be private relay
        email_verified: verified.email_verified,
        is_private_email: verified.is_private_email,
        real_user_status: verified.real_user_status
    };
}

/**
 * Check if user exists in S3 identity mapping
 */
async function checkExistingUser(appleUserId) {
    try {
        const key = `identities/apple:${appleUserId}`;
        const result = await s3.getObject({
            Bucket: BUCKET_NAME,
            Key: key
        }).promise();
        
        const serviceUserId = result.Body.toString('utf-8');
        
        // Load user data
        const userKey = `users/${serviceUserId}/profile.json`;
        const userResult = await s3.getObject({
            Bucket: BUCKET_NAME,
            Key: userKey
        }).promise();
        
        return JSON.parse(userResult.Body.toString('utf-8'));
        
    } catch (error) {
        if (error.code === 'NoSuchKey') {
            return null; // User doesn't exist
        }
        throw error;
    }
}

/**
 * Create new user with S3 identity persistence
 */
async function createNewUser(appleUser) {
    // Generate UUID for service user ID
    const serviceUserId = generateUUID();
    
    // Create user object
    const photolalaUser = {
        id: serviceUserId,
        email: appleUser.email,
        emailVerified: appleUser.email_verified,
        providers: [{
            type: 'apple',
            id: appleUser.sub,
            email: appleUser.email
        }],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
    };
    
    // Save to S3 - identity mapping
    await s3.putObject({
        Bucket: BUCKET_NAME,
        Key: `identities/apple:${appleUser.sub}`,
        Body: serviceUserId,
        ContentType: 'text/plain'
    }).promise();
    
    // Save to S3 - user profile
    await s3.putObject({
        Bucket: BUCKET_NAME,
        Key: `users/${serviceUserId}/profile.json`,
        Body: JSON.stringify(photolalaUser, null, 2),
        ContentType: 'application/json'
    }).promise();
    
    // Save email mapping if verified
    if (appleUser.email && appleUser.email_verified) {
        const emailHash = hashEmail(appleUser.email);
        await s3.putObject({
            Bucket: BUCKET_NAME,
            Key: `emails/${emailHash}`,
            Body: serviceUserId,
            ContentType: 'text/plain'
        }).promise();
    }
    
    return photolalaUser;
}

/**
 * Generate app-specific JWT token
 */
function generateAppToken(user) {
    // In production, use proper JWT library and secret management
    return jwt.sign(
        { 
            userId: user.id,
            email: user.email 
        },
        process.env.JWT_SECRET || 'your-secret-key',
        { 
            expiresIn: '7d',
            issuer: 'photolala'
        }
    );
}

/**
 * Hash email for privacy (same as iOS/Android implementation)
 */
function hashEmail(email) {
    const crypto = require('crypto');
    const normalized = email.toLowerCase().trim();
    return crypto.createHash('sha256').update(normalized).digest('hex');
}

/**
 * Generate UUID v4
 */
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

// Export for your server framework
module.exports = {
    handleAppleSignIn,
    verifyAppleIdToken
};

/**
 * Example Express server setup:
 * 
 * const express = require('express');
 * const app = express();
 * 
 * app.use(express.json());
 * app.post('/auth/apple', handleAppleSignIn);
 * 
 * app.listen(3000, () => {
 *     console.log('Apple auth backend running on port 3000');
 * });
 */

/**
 * Example Firebase Function:
 * 
 * exports.appleAuth = functions.https.onRequest(async (req, res) => {
 *     // Enable CORS
 *     res.set('Access-Control-Allow-Origin', '*');
 *     
 *     if (req.method === 'OPTIONS') {
 *         res.set('Access-Control-Allow-Methods', 'POST');
 *         res.set('Access-Control-Allow-Headers', 'Content-Type');
 *         res.status(204).send('');
 *         return;
 *     }
 *     
 *     if (req.method !== 'POST') {
 *         res.status(405).send('Method Not Allowed');
 *         return;
 *     }
 *     
 *     await handleAppleSignIn(req, res);
 * });
 */