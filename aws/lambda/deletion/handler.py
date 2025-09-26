"""
Account Deletion Lambda using S3 Batch Operations

Handles scheduled deletions and immediate deletion requests.
Uses S3's built-in Batch Operations for large-scale deletions.
No Docker containers or AWS Batch required.
"""

import os
import json
import boto3
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any, List
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configuration
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'development')

# Correct bucket mapping for each environment
BUCKET_MAPPING = {
    'development': 'photolala-dev',
    'staging': 'photolala-stage',
    'production': 'photolala-prod'
}
BUCKET_NAME = os.environ.get('BUCKET_NAME', BUCKET_MAPPING.get(ENVIRONMENT, 'photolala-dev'))
DELETION_THRESHOLD = int(os.environ.get('DELETION_THRESHOLD', '1000'))

# AWS clients
s3 = boto3.client('s3')
s3control = boto3.client('s3control')
sts = boto3.client('sts')

# Get account ID once
ACCOUNT_ID = sts.get_caller_identity()['Account']

# Grace periods by environment
GRACE_PERIODS = {
    'development': 180,      # 3 minutes
    'staging': 259200,       # 3 days
    'production': 2592000    # 30 days
}


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for account deletion.

    Event types:
    - immediate: Delete now (dev only)
    - scheduled: Process scheduled deletions
    - status: Check S3 Batch Operations job status
    """
    try:
        action = event.get('type', 'scheduled')
        logger.info(f"Processing {action} deletion request")

        if action == 'immediate':
            # Immediate deletion (development only)
            if ENVIRONMENT != 'development':
                return {
                    'statusCode': 403,
                    'body': json.dumps({
                        'error': 'Immediate deletion only allowed in development'
                    })
                }

            user_id = event.get('userId')
            if not user_id:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'userId required'})
                }

            result = delete_user_account(user_id)

        elif action == 'scheduled':
            # Process scheduled deletions
            result = process_scheduled_deletions()

        elif action == 'status':
            # Check S3 Batch job status
            job_id = event.get('jobId')
            if not job_id:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'jobId required'})
                }
            result = get_batch_job_status(job_id)

        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unknown action: {action}'})
            }

        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }

    except Exception as e:
        logger.error(f"Handler error: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def delete_user_account(user_id: str) -> Dict[str, Any]:
    """
    Delete a user account and all associated data.
    Uses direct deletion or S3 Batch Operations based on object count.
    """
    logger.info(f"Starting deletion for user {user_id}")

    # Count objects to determine deletion method
    object_count, objects_by_prefix = count_and_list_objects(user_id)
    logger.info(f"User {user_id} has {object_count} total objects")

    if object_count == 0:
        logger.info(f"No objects found for user {user_id}")
        # Still remove identity mappings and scheduled deletion
        remove_identity_mappings(user_id)
        remove_scheduled_deletion(user_id)
        return {
            'status': 'completed',
            'userId': user_id,
            'objectCount': 0,
            'method': 'none',
            'message': 'No objects to delete'
        }

    # Always clean up identity mappings and scheduled deletion immediately
    # This allows re-registration right away and simplifies testing
    try:
        remove_identity_mappings(user_id)
        remove_scheduled_deletion(user_id)
        logger.info(f"Cleaned up identity mappings and scheduled deletion for user {user_id}")
    except Exception as e:
        logger.error(f"Error cleaning up mappings for user {user_id}: {str(e)}")
        # Don't fail the whole operation if cleanup fails

    if object_count <= DELETION_THRESHOLD:
        # Direct deletion for small accounts
        logger.info(f"Using direct deletion for {object_count} objects")
        deleted_count = perform_direct_deletion(objects_by_prefix)

        return {
            'status': 'completed',
            'userId': user_id,
            'objectCount': object_count,
            'deletedCount': deleted_count,
            'method': 'direct',
            'message': 'Account deleted successfully'
        }

    else:
        # Use S3 Batch Operations for large accounts
        logger.info(f"Creating S3 Batch Operations job for {object_count} objects")
        job_id = create_batch_operations_job(user_id, objects_by_prefix)

        return {
            'status': 'batch_job_created',
            'userId': user_id,
            'jobId': job_id,
            'objectCount': object_count,
            'method': 'batch',
            'message': f'Batch job {job_id} created for {object_count} objects'
        }


def count_and_list_objects(user_id: str) -> tuple[int, Dict[str, List[str]]]:
    """
    Count objects and return them organized by prefix.
    Returns: (total_count, {prefix: [keys]})
    """
    prefixes = [
        f'photos/{user_id}/',
        f'thumbnails/{user_id}/',
        f'catalogs/{user_id}/',
        f'users/{user_id}/'
    ]

    total_count = 0
    objects_by_prefix = {}

    for prefix in prefixes:
        keys = []
        paginator = s3.get_paginator('list_objects_v2')

        for page in paginator.paginate(Bucket=BUCKET_NAME, Prefix=prefix):
            if 'Contents' in page:
                for obj in page['Contents']:
                    keys.append(obj['Key'])
                    total_count += 1

        if keys:
            objects_by_prefix[prefix] = keys
            logger.info(f"Found {len(keys)} objects in {prefix}")

    return total_count, objects_by_prefix


def perform_direct_deletion(objects_by_prefix: Dict[str, List[str]]) -> int:
    """
    Directly delete objects using S3 delete_objects API.
    Returns number of successfully deleted objects.
    """
    total_deleted = 0

    for prefix, keys in objects_by_prefix.items():
        # S3 delete_objects has a limit of 1000 objects per request
        for i in range(0, len(keys), 1000):
            batch = keys[i:i + 1000]
            delete_request = {'Objects': [{'Key': key} for key in batch]}

            try:
                response = s3.delete_objects(
                    Bucket=BUCKET_NAME,
                    Delete=delete_request
                )

                deleted = len(response.get('Deleted', []))
                total_deleted += deleted
                logger.info(f"Deleted {deleted} objects from {prefix}")

                # Log any errors
                errors = response.get('Errors', [])
                if errors:
                    logger.error(f"Failed to delete {len(errors)} objects: {errors[:5]}")

            except Exception as e:
                logger.error(f"Error deleting batch from {prefix}: {str(e)}")

    return total_deleted


def create_batch_operations_job(user_id: str, objects_by_prefix: Dict[str, List[str]]) -> str:
    """
    Create an S3 Batch Operations job for large-scale deletion.
    Returns the job ID for tracking.
    """
    job_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')

    # Create manifest file listing all objects to delete
    manifest_key = f'batch-jobs/manifests/{timestamp}/{user_id}-manifest.csv'
    manifest_content = create_deletion_manifest(objects_by_prefix)

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=manifest_key,
        Body=manifest_content.encode('utf-8'),
        ContentType='text/csv'
    )

    # Get manifest ETag for job creation
    manifest_etag = s3.head_object(Bucket=BUCKET_NAME, Key=manifest_key)['ETag'].strip('"')

    # Create completion report location
    report_prefix = f'batch-jobs/reports/{timestamp}/{user_id}'

    # Create S3 Batch Operations job
    response = s3control.create_job(
        AccountId=ACCOUNT_ID,
        ConfirmationRequired=False,
        Operation={
            'S3DeleteObject': {}  # Delete the actual objects
        },
        Manifest={
            'Spec': {
                'Format': 'S3BatchOperations_CSV_20180820',
                'Fields': ['Bucket', 'Key']
            },
            'Location': {
                'ObjectArn': f'arn:aws:s3:::{BUCKET_NAME}/{manifest_key}',
                'ETag': manifest_etag
            }
        },
        Priority=10,
        Report={
            'Enabled': True,
            'Bucket': f'arn:aws:s3:::{BUCKET_NAME}',
            'Prefix': report_prefix,
            'Format': 'Report_CSV_20180820',
            'ReportScope': 'FailedTasksOnly'
        },
        RoleArn=f'arn:aws:iam::{ACCOUNT_ID}:role/S3BatchOperationsRole',
        Tags=[
            {'Key': 'UserId', 'Value': user_id},
            {'Key': 'Type', 'Value': 'AccountDeletion'},
            {'Key': 'Environment', 'Value': ENVIRONMENT}
        ],
        Description=f'Delete account data for user {user_id}'
    )

    job_id = response['JobId']
    logger.info(f"Created S3 Batch Operations job {job_id} for user {user_id}")

    # Store job metadata for tracking
    metadata = {
        'jobId': job_id,
        'userId': user_id,
        'objectCount': sum(len(keys) for keys in objects_by_prefix.values()),
        'createdAt': datetime.utcnow().isoformat(),
        'manifestKey': manifest_key,
        'reportPrefix': report_prefix
    }

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=f'batch-jobs/metadata/{job_id}.json',
        Body=json.dumps(metadata),
        ContentType='application/json'
    )

    return job_id


def create_deletion_manifest(objects_by_prefix: Dict[str, List[str]]) -> str:
    """
    Create CSV manifest for S3 Batch Operations.
    Format: bucket,key (one per line)
    """
    lines = []

    for prefix, keys in objects_by_prefix.items():
        for key in keys:
            lines.append(f'{BUCKET_NAME},{key}')

    return '\n'.join(lines)


def get_batch_job_status(job_id: str) -> Dict[str, Any]:
    """
    Check the status of an S3 Batch Operations job.
    """
    try:
        response = s3control.describe_job(
            AccountId=ACCOUNT_ID,
            JobId=job_id
        )

        job = response['Job']

        result = {
            'jobId': job_id,
            'status': job['Status'],
            'createdAt': job.get('CreationTime', '').isoformat() if job.get('CreationTime') else None,
            'priority': job.get('Priority'),
            'progressSummary': {}
        }

        # Add progress details if available
        if 'ProgressSummary' in job:
            progress = job['ProgressSummary']
            result['progressSummary'] = {
                'totalTasks': progress.get('TotalNumberOfTasks', 0),
                'succeeded': progress.get('NumberOfTasksSucceeded', 0),
                'failed': progress.get('NumberOfTasksFailed', 0)
            }

        # Note: Identity mappings and scheduled deletion are cleaned up immediately
        # after job creation, not after completion

        return result

    except s3control.exceptions.NoSuchJob:
        return {
            'jobId': job_id,
            'status': 'NotFound',
            'error': 'Job not found'
        }
    except Exception as e:
        logger.error(f"Error getting job status: {str(e)}")
        return {
            'jobId': job_id,
            'status': 'Error',
            'error': str(e)
        }


def process_scheduled_deletions() -> Dict[str, Any]:
    """
    Process all accounts scheduled for deletion today.
    """
    from datetime import timezone
    now = datetime.now(timezone.utc)
    date_key = now.strftime('%Y-%m-%d')

    logger.info(f"Processing scheduled deletions for {date_key}")

    # List scheduled deletion files
    prefix = f'scheduled-deletions/{date_key}/'

    try:
        response = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix=prefix)

        if 'Contents' not in response:
            logger.info("No scheduled deletions found")
            return {
                'processed': 0,
                'message': 'No scheduled deletions for today'
            }

        results = []

        for obj in response['Contents']:
            # Extract user ID from filename
            filename = obj['Key'].split('/')[-1]
            user_id = filename.replace('.json', '')

            # Read deletion metadata
            try:
                deletion_obj = s3.get_object(Bucket=BUCKET_NAME, Key=obj['Key'])
                deletion_data = json.loads(deletion_obj['Body'].read())

                # Check if deletion is due
                delete_on = datetime.fromisoformat(
                    deletion_data['deleteOn'].replace('Z', '+00:00')
                )

                if delete_on <= now:
                    logger.info(f"Processing deletion for user {user_id}")
                    result = delete_user_account(user_id)
                    results.append({
                        'userId': user_id,
                        **result
                    })
                else:
                    logger.info(f"Deletion for {user_id} not due yet (scheduled for {delete_on})")

            except Exception as e:
                logger.error(f"Error processing deletion for {user_id}: {str(e)}")
                results.append({
                    'userId': user_id,
                    'status': 'error',
                    'error': str(e)
                })

        return {
            'processed': len(results),
            'results': results
        }

    except Exception as e:
        logger.error(f"Error listing scheduled deletions: {str(e)}")
        return {
            'processed': 0,
            'error': str(e)
        }


def remove_identity_mappings(user_id: str) -> None:
    """
    Remove all identity mappings for a user.
    Phase 1 uses flat keys like: identities/apple:externalId
    """
    logger.info(f"Removing identity mappings for user {user_id}")

    # List all files under identities/ prefix (flat structure)
    prefix = 'identities/'
    removed_count = 0

    paginator = s3.get_paginator('list_objects_v2')

    for page in paginator.paginate(Bucket=BUCKET_NAME, Prefix=prefix):
        if 'Contents' not in page:
            continue

        for obj in page['Contents']:
            # Skip the directory marker itself
            if obj['Key'] == prefix:
                continue

            try:
                # Read mapping to check if it belongs to this user
                mapping_obj = s3.get_object(
                    Bucket=BUCKET_NAME,
                    Key=obj['Key']
                )
                content = mapping_obj['Body'].read().decode('utf-8').strip()

                if content == user_id:
                    # Delete this mapping
                    s3.delete_object(
                        Bucket=BUCKET_NAME,
                        Key=obj['Key']
                    )
                    removed_count += 1
                    logger.info(f"Removed identity mapping: {obj['Key']}")

            except Exception as e:
                logger.error(f"Error checking identity mapping {obj['Key']}: {str(e)}")

    logger.info(f"Removed {removed_count} identity mappings for user {user_id}")


def remove_scheduled_deletion(user_id: str) -> None:
    """
    Remove scheduled deletion entry after processing.
    """
    logger.info(f"Removing scheduled deletion entry for user {user_id}")

    # Search for the scheduled deletion file
    prefix = 'scheduled-deletions/'
    paginator = s3.get_paginator('list_objects_v2')

    for page in paginator.paginate(Bucket=BUCKET_NAME, Prefix=prefix):
        if 'Contents' not in page:
            continue

        for obj in page['Contents']:
            if user_id in obj['Key']:
                try:
                    s3.delete_object(
                        Bucket=BUCKET_NAME,
                        Key=obj['Key']
                    )
                    logger.info(f"Removed scheduled deletion: {obj['Key']}")
                    return
                except Exception as e:
                    logger.error(f"Error removing scheduled deletion: {str(e)}")