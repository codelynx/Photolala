package com.electricwoods.photolala.di

import com.amazonaws.auth.AWSCredentialsProvider
import com.amazonaws.regions.Region
import com.amazonaws.regions.Regions
import com.amazonaws.services.s3.AmazonS3Client
import com.electricwoods.photolala.services.AWSCredentialProvider
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AWSModule {
    
    @Provides
    @Singleton
    fun provideAWSCredentialsProvider(): AWSCredentialsProvider {
        return AWSCredentialProvider()
    }
    
    @Provides
    @Singleton
    fun provideAmazonS3Client(
        credentialsProvider: AWSCredentialsProvider
    ): AmazonS3Client {
        val awsCredentialProvider = credentialsProvider as AWSCredentialProvider
        val regionString = awsCredentialProvider.getRegion()
        
        // Map region string to Regions enum
        val region = when (regionString) {
            "us-east-1" -> Regions.US_EAST_1
            "us-west-2" -> Regions.US_WEST_2
            "eu-west-1" -> Regions.EU_WEST_1
            // Add more regions as needed
            else -> Regions.US_EAST_1
        }
        
        return AmazonS3Client(credentialsProvider).apply {
            setRegion(Region.getRegion(region))
        }
    }
}