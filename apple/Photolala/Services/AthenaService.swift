//
//  AthenaService.swift
//  Photolala
//
//  Simplified Athena service for apple-x
//

import Foundation
@preconcurrency import AWSAthena
@preconcurrency import AWSClientRuntime
@preconcurrency import AWSSDKIdentity
@preconcurrency import SmithyIdentity
import OSLog

/// Simplified Athena service for querying catalog data
actor AthenaService {
	static let shared = AthenaService()
	private let logger = Logger(subsystem: "com.photolala", category: "AthenaService")
	private nonisolated(unsafe) var client: AthenaClient?
	private let region = "us-east-1"
	private let database = "photolala"
	private let workGroup = "primary"

	private init() {}

	/// Initialize the Athena client
	func initialize() async throws {
		guard client == nil else { return }

		// Get credentials based on environment
		let bucketName = await MainActor.run {
			EnvironmentHelper.getCurrentBucket()
		}
		let accessKeyEnum: CredentialKey
		let secretKeyEnum: CredentialKey

		switch bucketName {
		case "photolala-dev":
			accessKeyEnum = .AWS_ACCESS_KEY_ID_DEV
			secretKeyEnum = .AWS_SECRET_ACCESS_KEY_DEV
		case "photolala-stage":
			accessKeyEnum = .AWS_ACCESS_KEY_ID_STAGE
			secretKeyEnum = .AWS_SECRET_ACCESS_KEY_STAGE
		default:
			accessKeyEnum = .AWS_ACCESS_KEY_ID_PROD
			secretKeyEnum = .AWS_SECRET_ACCESS_KEY_PROD
		}

		let credentials = await MainActor.run {
			(
				accessKey: Credentials.decryptCached(accessKeyEnum),
				secretKey: Credentials.decryptCached(secretKeyEnum)
			)
		}

		guard let accessKey = credentials.accessKey,
			  let secretKey = credentials.secretKey else {
			throw AthenaError.credentialsNotFound
		}

		// Create Athena client
		let credentialIdentity = AWSCredentialIdentity(
			accessKey: accessKey,
			secret: secretKey
		)
		let credentialResolver = StaticAWSCredentialIdentityResolver(credentialIdentity)

		let config = try await AthenaClient.AthenaClientConfiguration(
			awsCredentialIdentityResolver: credentialResolver,
			region: region
		)

		self.client = AthenaClient(config: config)
		logger.info("Athena client initialized")
	}

	/// Execute a query and wait for results
	func executeQuery(_ sql: String) async throws -> [[String: String]] {
		try await initialize()
		guard let client = client else { throw AthenaError.clientNotInitialized }

		// Get output location based on environment
		let bucketName = await MainActor.run {
			EnvironmentHelper.getCurrentBucket()
		}
		let outputLocation = "s3://\(bucketName)/athena-results/"

		// Start query execution
		let startInput = StartQueryExecutionInput(
			queryExecutionContext: .init(database: database),
			queryString: sql,
			resultConfiguration: .init(outputLocation: outputLocation),
			workGroup: workGroup
		)

		let startOutput = try await client.startQueryExecution(input: startInput)
		guard let queryExecutionId = startOutput.queryExecutionId else {
			throw AthenaError.queryExecutionFailed
		}

		// Wait for query completion
		var status: AthenaClientTypes.QueryExecutionState = .queued
		var attempts = 0
		let maxAttempts = 60 // 30 seconds timeout

		while status == .queued || status == .running {
			if attempts > maxAttempts {
				throw AthenaError.queryTimeout
			}

			try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

			let statusInput = GetQueryExecutionInput(queryExecutionId: queryExecutionId)
			let statusOutput = try await client.getQueryExecution(input: statusInput)

			status = statusOutput.queryExecution?.status?.state ?? .failed
			attempts += 1
		}

		// Check for failure
		if status == .failed || status == .cancelled {
			let statusInput = GetQueryExecutionInput(queryExecutionId: queryExecutionId)
			let statusOutput = try await client.getQueryExecution(input: statusInput)
			let error = statusOutput.queryExecution?.status?.stateChangeReason ?? "Unknown error"
			throw AthenaError.queryFailed(error)
		}

		// Get results
		let resultsInput = GetQueryResultsInput(queryExecutionId: queryExecutionId)
		let resultsOutput = try await client.getQueryResults(input: resultsInput)

		// Parse results
		var results: [[String: String]] = []
		let columns = resultsOutput.resultSet?.resultSetMetadata?.columnInfo ?? []
		let rows = resultsOutput.resultSet?.rows ?? []

		// Skip header row if present
		let dataRows = rows.count > 0 && rows[0].data?.first?.varCharValue != nil ? Array(rows.dropFirst()) : rows

		for row in dataRows {
			var record: [String: String] = [:]
			for (index, column) in columns.enumerated() {
				let columnName = column.name ?? "column\(index)"
				let value = row.data?[safe: index]?.varCharValue ?? ""
				record[columnName] = value
			}
			results.append(record)
		}

		return results
	}

	/// Get catalog for a user
	func getCatalog(userId: String, year: Int? = nil) async throws -> [[String: String]] {
		var sql = """
			SELECT DISTINCT
				userId,
				year,
				month,
				md5,
				size,
				timestamp,
				true as isStarred
			FROM photolala.catalog_current
			WHERE userId = '\(userId)'
			"""

		if let year = year {
			sql += " AND year = \(year)"
		}

		sql += " ORDER BY timestamp DESC"

		return try await executeQuery(sql)
	}
}

// MARK: - Error Types
enum AthenaError: LocalizedError {
	case credentialsNotFound
	case clientNotInitialized
	case queryExecutionFailed
	case queryTimeout
	case queryFailed(String)

	var errorDescription: String? {
		switch self {
		case .credentialsNotFound:
			return "AWS credentials not found"
		case .clientNotInitialized:
			return "Athena client not initialized"
		case .queryExecutionFailed:
			return "Failed to start query execution"
		case .queryTimeout:
			return "Query execution timed out"
		case .queryFailed(let reason):
			return "Query failed: \(reason)"
		}
	}
}

// MARK: - Helper Extensions
private extension Array where Self: Sendable {
	nonisolated subscript(safe index: Int) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}
}
