/**
 * AWS Lambda function for Photolala Apple Sign-In
 * Updated to use AWS SDK v3 (pre-installed in Lambda Node.js 18)
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const crypto = require('crypto');

// Initialize AWS services
const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

// Configuration
const BUCKET_NAME = 'photolala';
const APPLE_SERVICE_ID = process.env.APPLE_SERVICE_ID || 'com.electricwoods.photolala.service';

// Apple's public key client
const appleClient = jwksClient({
    jwksUri: 'https://appleid.apple.com/auth/keys',
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 10
});

/**
 * Lambda handler function
 */
exports.handler = async (event) => {
    console.log('Apple auth request:', event.httpMethod, event.path);
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: getCorsHeaders(),
            body: ''
        };
    }
    
    try {
        // Parse request body
        const body = JSON.parse(event.body || '{}');
        const { id_token, authorization_code } = body;
        
        if (!id_token) {
            return errorResponse('Missing id_token', 400);
        }
        
        // For testing - return mock response for "test" token
        if (id_token === 'test') {
            return errorResponse('Invalid token format - test token detected', 400);
        }
        
        // Verify Apple's ID token
        console.log('Verifying Apple ID token...');
        const appleUser = await verifyAppleIdToken(id_token);
        console.log('Apple user verified:', appleUser.sub);
        
        // Check if user exists
        const providerId = `apple:${appleUser.sub}`;
        const existingUserId = await getExistingUserId(providerId);
        
        let response;
        if (existingUserId) {
            console.log('Existing user found:', existingUserId);
            response = {
                isNewUser: false,
                userId: existingUserId,
                providerId: providerId,
                email: appleUser.email
            };
        } else {
            console.log('Creating new user...');
            const newUserId = generateUUID();
            
            // Create identity mapping
            await s3Client.send(new PutObjectCommand({
                Bucket: BUCKET_NAME,
                Key: `identities/${providerId}`,
                Body: newUserId,
                ContentType: 'text/plain'
            }));
            
            // Create email mapping if available
            if (appleUser.email && appleUser.email_verified) {
                const emailHash = hashEmail(appleUser.email);
                await s3Client.send(new PutObjectCommand({
                    Bucket: BUCKET_NAME,
                    Key: `emails/${emailHash}`,
                    Body: newUserId,
                    ContentType: 'text/plain'
                }));
            }
            
            response = {
                isNewUser: true,
                userId: newUserId,
                providerId: providerId,
                email: appleUser.email
            };
        }
        
        console.log('Apple auth successful');
        return successResponse(response);
        
    } catch (error) {
        console.error('Apple auth error:', error);
        return errorResponse(error.message, 401);
    }
};

/**
 * Verify Apple's ID token
 */
async function verifyAppleIdToken(idToken) {
    // Decode to get key ID
    const decoded = jwt.decode(idToken, { complete: true });
    if (!decoded) {
        throw new Error('Invalid token format');
    }
    
    // Get Apple's public key
    const key = await getApplePublicKey(decoded.header.kid);
    
    // Verify token
    const verified = jwt.verify(idToken, key, {
        issuer: 'https://appleid.apple.com',
        audience: APPLE_SERVICE_ID,
        algorithms: ['RS256']
    });
    
    // Validate claims
    if (!verified.sub) {
        throw new Error('Token missing user ID');
    }
    
    return {
        sub: verified.sub,
        email: verified.email,
        email_verified: verified.email_verified === 'true',
        is_private_email: verified.is_private_email === 'true'
    };
}

/**
 * Get Apple's public key for verification
 */
async function getApplePublicKey(kid) {
    return new Promise((resolve, reject) => {
        appleClient.getSigningKey(kid, (err, key) => {
            if (err) {
                reject(err);
            } else {
                resolve(key.getPublicKey());
            }
        });
    });
}

/**
 * Check if user exists in S3
 */
async function getExistingUserId(providerId) {
    try {
        const command = new GetObjectCommand({
            Bucket: BUCKET_NAME,
            Key: `identities/${providerId}`
        });
        
        const result = await s3Client.send(command);
        
        // Convert stream to string
        const streamToString = async (stream) => {
            const chunks = [];
            for await (const chunk of stream) {
                chunks.push(chunk);
            }
            return Buffer.concat(chunks).toString('utf-8');
        };
        
        return await streamToString(result.Body);
    } catch (error) {
        if (error.name === 'NoSuchKey') {
            return null;
        }
        throw error;
    }
}

/**
 * Hash email for privacy
 */
function hashEmail(email) {
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

/**
 * Get CORS headers
 */
function getCorsHeaders() {
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    };
}

/**
 * Success response helper
 */
function successResponse(data) {
    return {
        statusCode: 200,
        headers: {
            ...getCorsHeaders(),
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            success: true,
            ...data
        })
    };
}

/**
 * Error response helper
 */
function errorResponse(message, statusCode = 400) {
    return {
        statusCode,
        headers: {
            ...getCorsHeaders(),
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            success: false,
            error: message
        })
    };
}