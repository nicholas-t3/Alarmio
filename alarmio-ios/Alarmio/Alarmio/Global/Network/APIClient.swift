//
//  APIClient.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import Supabase
import SwiftUI

// MARK: - API Error

enum APIError: LocalizedError {
    case unauthorized
    case networkUnavailable
    case serverError(statusCode: Int, body: String)
    case noSession
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please restart the app."
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .serverError(let code, _):
            return "Server error (\(code)). Please try again later."
        case .noSession:
            return "Not signed in. Please restart the app."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - API Client

@MainActor
final class APIClient {

    // MARK: - Singleton

    static let shared = APIClient()

    // MARK: - Dependencies

    private let supabase = SupabaseClient.shared

    // MARK: - Init

    private init() {}

    // MARK: - Edge Functions

    func invokeFunction<Request: Encodable, Response: Decodable>(
        _ name: String,
        body: Request
    ) async throws(APIError) -> Response {
        do {
            try await ensureSession()

            let response: Response = try await supabase.client.functions.invoke(
                name,
                options: FunctionInvokeOptions(body: body)
            )
            return response
        } catch let error as APIError {
            throw error
        } catch let error as FunctionsError {
            throw mapFunctionsError(error)
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw .unknown(error)
        }
    }

    // MARK: - Storage

    func downloadFromStorage(bucket: String, path: String) async throws(APIError) -> Data {
        do {
            try await ensureSession()

            print("[APIClient] Storage download start: bucket=\(bucket) path=\(path)")
            let t0 = Date()
            let bytes = try await supabase.client.storage
                .from(bucket)
                .download(path: path)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            let firstHex = bytes.prefix(16).map { String(format: "%02x", $0) }.joined()
            print("[APIClient] Storage download done: bytes=\(bytes.count) in \(ms)ms firstBytesHex=\(firstHex)")
            return bytes
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw .unknown(error)
        }
    }

    // MARK: - Auth

    func ensureSession() async throws(APIError) {
        do {
            if let session = try? await supabase.client.auth.session {
                if session.isExpired {
                    try await supabase.client.auth.refreshSession()
                    print("[APIClient] Session refreshed")
                }
                return
            }

            try await supabase.client.auth.signInAnonymously()
            print("[APIClient] Signed in anonymously")
        } catch {
            print("[APIClient] Auth failed: \(error)")
            throw .noSession
        }
    }

    var currentUserId: UUID? {
        supabase.client.auth.currentUser?.id
    }

    // MARK: - Error Mapping

    private func mapFunctionsError(_ error: FunctionsError) -> APIError {
        switch error {
        case .httpError(let code, let data):
            let body = String(data: data, encoding: .utf8) ?? "non-utf8"
            print("[APIClient] Function HTTP \(code): \(body)")
            if code == 401 { return .unauthorized }
            return .serverError(statusCode: code, body: body)
        default:
            return .unknown(error)
        }
    }

    private func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost:
            return .networkUnavailable
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Environment Key

private struct APIClientKey: EnvironmentKey {
    @MainActor static let defaultValue = APIClient.shared
}

extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
