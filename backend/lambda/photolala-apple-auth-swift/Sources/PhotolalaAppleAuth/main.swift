import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import AWSS3
import JWTKit
import AsyncHTTPClient
import Crypto

// MARK: - Lambda Handler

@main
struct PhotolalaAppleAuthHandler: SimpleLambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let s3Client: S3Client
    let httpClient: HTTPClient
    let appleJWKSURL = "https://appleid.apple.com/auth/keys"
    let serviceID = Lambda.env("APPLE_SERVICE_ID") ?? "com.electricwoods.photolala.service"
    
    init(context: LambdaInitializationContext) async throws {
        self.s3Client = try S3Client(region: "us-east-1")
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    }
    
    func handle(_ event: Event, context: LambdaContext) async throws -> Output {
        context.logger.info("Apple auth request received")
        
        // Handle CORS preflight
        if event.requestContext.http.method == .OPTIONS {
            return APIGatewayV2Response(
                statusCode: .ok,
                headers: getCORSHeaders()
            )
        }
        
        // Parse request body
        guard let body = event.body,
              let data = body.data(using: .utf8),
              let request = try? JSONDecoder().decode(AppleAuthRequest.self, from: data) else {
            return errorResponse("Invalid request body", statusCode: .badRequest)
        }
        
        do {
            // Verify Apple ID token
            let appleUser = try await verifyAppleToken(request.idToken)
            context.logger.info("Apple user verified", metadata: ["sub": .string(appleUser.sub)])
            
            // Check if user exists
            let providerId = "apple:\(appleUser.sub)"
            let existingUserId = try await getExistingUserId(providerId: providerId)
            
            let response: AppleAuthResponse
            if let userId = existingUserId {
                context.logger.info("Existing user found", metadata: ["userId": .string(userId)])
                response = AppleAuthResponse(
                    success: true,
                    isNewUser: false,
                    userId: userId,
                    providerId: providerId,
                    email: appleUser.email
                )
            } else {
                // Create new user
                let newUserId = UUID().uuidString
                context.logger.info("Creating new user", metadata: ["userId": .string(newUserId)])
                
                // Save identity mapping to S3
                try await createIdentityMapping(providerId: providerId, userId: newUserId)
                
                // Create email mapping if available
                if let email = appleUser.email, appleUser.emailVerified {
                    let emailHash = hashEmail(email)
                    try await createEmailMapping(emailHash: emailHash, userId: newUserId)
                }
                
                response = AppleAuthResponse(
                    success: true,
                    isNewUser: true,
                    userId: newUserId,
                    providerId: providerId,
                    email: appleUser.email
                )
            }
            
            return successResponse(response)
            
        } catch {
            context.logger.error("Apple auth error", metadata: ["error": .string(error.localizedDescription)])
            return errorResponse(error.localizedDescription, statusCode: .unauthorized)
        }
    }
    
    // MARK: - Apple Token Verification
    
    func verifyAppleToken(_ idToken: String) async throws -> AppleUser {
        // Fetch Apple's public keys
        let jwks = try await fetchApplePublicKeys()
        
        // Decode and verify the token
        let signers = JWTSigners()
        try signers.use(jwks: jwks)
        
        let payload = try signers.verify(idToken, as: AppleTokenPayload.self)
        
        // Validate claims
        guard payload.iss == "https://appleid.apple.com" else {
            throw AppleAuthError.invalidIssuer
        }
        
        guard payload.aud.contains(serviceID) else {
            throw AppleAuthError.invalidAudience
        }
        
        guard payload.exp > Date() else {
            throw AppleAuthError.tokenExpired
        }
        
        return AppleUser(
            sub: payload.sub,
            email: payload.email,
            emailVerified: payload.emailVerified ?? false
        )
    }
    
    func fetchApplePublicKeys() async throws -> JWKS {
        let request = HTTPClientRequest(url: appleJWKSURL)
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB max
        guard let data = body.readData(length: body.readableBytes) else {
            throw AppleAuthError.failedToFetchKeys
        }
        
        return try JSONDecoder().decode(JWKS.self, from: data)
    }
    
    // MARK: - S3 Operations
    
    func getExistingUserId(providerId: String) async throws -> String? {
        let key = "identities/\(providerId)"
        
        do {
            let input = GetObjectInput(
                bucket: "photolala",
                key: key
            )
            
            let output = try await s3Client.getObject(input: input)
            
            guard let body = output.body,
                  let data = try await body.readData(),
                  let userId = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            return userId
            
        } catch let error as AWSS3.NoSuchKey {
            return nil // User doesn't exist
        } catch {
            throw error
        }
    }
    
    func createIdentityMapping(providerId: String, userId: String) async throws {
        let key = "identities/\(providerId)"
        let input = PutObjectInput(
            body: .data(userId.data(using: .utf8)!),
            bucket: "photolala",
            contentType: "text/plain",
            key: key
        )
        
        _ = try await s3Client.putObject(input: input)
    }
    
    func createEmailMapping(emailHash: String, userId: String) async throws {
        let key = "emails/\(emailHash)"
        let input = PutObjectInput(
            body: .data(userId.data(using: .utf8)!),
            bucket: "photolala",
            contentType: "text/plain",
            key: key
        )
        
        _ = try await s3Client.putObject(input: input)
    }
    
    // MARK: - Helpers
    
    func hashEmail(_ email: String) -> String {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: normalized.data(using: .utf8)!)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func getCORSHeaders() -> [String: String] {
        [
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "OPTIONS,POST"
        ]
    }
    
    func successResponse<T: Encodable>(_ data: T) -> APIGatewayV2Response {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let body = try? encoder.encode(data),
              let bodyString = String(data: body, encoding: .utf8) else {
            return errorResponse("Failed to encode response")
        }
        
        return APIGatewayV2Response(
            statusCode: .ok,
            headers: getCORSHeaders().merging(["Content-Type": "application/json"]) { $1 },
            body: bodyString
        )
    }
    
    func errorResponse(_ message: String, statusCode: HTTPResponseStatus = .badRequest) -> APIGatewayV2Response {
        let error = ErrorResponse(success: false, error: message)
        let encoder = JSONEncoder()
        
        guard let body = try? encoder.encode(error),
              let bodyString = String(data: body, encoding: .utf8) else {
            return APIGatewayV2Response(statusCode: statusCode)
        }
        
        return APIGatewayV2Response(
            statusCode: statusCode,
            headers: getCORSHeaders().merging(["Content-Type": "application/json"]) { $1 },
            body: bodyString
        )
    }
}

// MARK: - Data Models

struct AppleAuthRequest: Decodable {
    let idToken: String
    let authorizationCode: String?
}

struct AppleAuthResponse: Encodable {
    let success: Bool
    let isNewUser: Bool
    let userId: String
    let providerId: String
    let email: String?
}

struct ErrorResponse: Encodable {
    let success: Bool
    let error: String
}

struct AppleUser {
    let sub: String
    let email: String?
    let emailVerified: Bool
}

struct AppleTokenPayload: JWTPayload {
    let iss: String
    let aud: [String]
    let exp: Date
    let iat: Date
    let sub: String
    let email: String?
    let emailVerified: Bool?
    
    enum CodingKeys: String, CodingKey {
        case iss, aud, exp, iat, sub, email
        case emailVerified = "email_verified"
    }
    
    func verify(using signer: JWTSigner) throws {
        // Verification is done by JWTKit
    }
}

// MARK: - Errors

enum AppleAuthError: Error, LocalizedError {
    case invalidIssuer
    case invalidAudience
    case tokenExpired
    case failedToFetchKeys
    
    var errorDescription: String? {
        switch self {
        case .invalidIssuer: return "Invalid token issuer"
        case .invalidAudience: return "Invalid token audience"
        case .tokenExpired: return "Token has expired"
        case .failedToFetchKeys: return "Failed to fetch Apple's public keys"
        }
    }
}

// MARK: - Extensions

extension HTTPClientResponse.Body {
    func readData() async throws -> Data? {
        let bytes = try await self.collect(upTo: 1024 * 1024) // 1MB max
        return bytes.readData(length: bytes.readableBytes)
    }
}