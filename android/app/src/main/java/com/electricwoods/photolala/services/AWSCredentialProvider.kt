package com.electricwoods.photolala.services

import com.amazonaws.auth.AWSCredentials
import com.amazonaws.auth.AWSCredentialsProvider
import com.amazonaws.auth.BasicAWSCredentials
import com.electricwoods.photolala.utils.Credentials
import com.electricwoods.photolala.utils.CredentialKey
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Provides AWS credentials from encrypted storage
 */
@Singleton
class AWSCredentialProvider @Inject constructor() : AWSCredentialsProvider {
    
    private var cachedCredentials: AWSCredentials? = null
    
    override fun getCredentials(): AWSCredentials {
        // Return cached credentials if available
        cachedCredentials?.let { return it }
        
        // Decrypt credentials from encrypted storage
        val accessKeyId = Credentials.decrypt(CredentialKey.AWS_ACCESS_KEY_ID)
            ?: throw IllegalStateException("Failed to decrypt AWS_ACCESS_KEY_ID")
            
        val secretAccessKey = Credentials.decrypt(CredentialKey.AWS_SECRET_ACCESS_KEY)
            ?: throw IllegalStateException("Failed to decrypt AWS_SECRET_ACCESS_KEY")
        
        // Create and cache credentials
        cachedCredentials = BasicAWSCredentials(accessKeyId, secretAccessKey)
        
        return cachedCredentials!!
    }
    
    override fun refresh() {
        // Clear cached credentials to force re-decryption
        cachedCredentials = null
    }
    
    fun getRegion(): String {
        return Credentials.decrypt(CredentialKey.AWS_DEFAULT_REGION) ?: "us-east-1"
    }
}