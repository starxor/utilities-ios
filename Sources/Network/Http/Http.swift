//
// Http
// EE Utilities
//
// Copyright (c) 2015 Eugene Egorov.
// License: MIT, https://github.com/eugeneego/utilities-ios/blob/master/LICENSE
//

import Foundation

public typealias HttpCompletion = (HTTPURLResponse?, Data?, HttpError?) -> Void

public protocol Http {
    func data(request: URLRequest, completion: @escaping HttpCompletion)

    func urlWithParameters(url: URL, parameters: [String: String]) -> URL
    func request(method: String, url: URL, urlParameters: [String: String],
        headers: [String: String], body: Data?) -> NSMutableURLRequest
}

public enum HttpError: Error {
    case nonHttpResponse(response: URLResponse)
    case badUrl
    case parsingFailed
    case error(error: Error?)
    case status(code: Int, error: Error?)
}

public enum HttpMethod {
    case get
    case head
    case post
    case put
    case patch
    case delete
    case trace
    case options
    case connect
    case custom(String)

    public var value: String {
        switch self {
            case .get: return "GET"
            case .head: return "HEAD"
            case .post: return "POST"
            case .put: return "PUT"
            case .patch: return "PATCH"
            case .delete: return "DELETE"
            case .trace: return "TRACE"
            case .options: return "OPTIONS"
            case .connect: return "CONNECT"
            case .custom(let value): return value
        }
    }
}

public extension Http {
    public func data(
        method: HttpMethod, url: URL, urlParameters: [String: String],
        headers: [String: String], body: Data?, completion: @escaping HttpCompletion
    ) {
        let req = request(method: method, url: url, urlParameters: urlParameters, headers: headers, body: body)
        data(request: req as URLRequest, completion: completion)
    }

    public func data<T: HttpSerializer>(
        request: URLRequest, serializer: T,
        completion: @escaping (HTTPURLResponse?, T.Value?, HttpError?) -> Void
    ) {
        data(request: request) { response, data, error in
            let object = serializer.deserialize(data)
            var error = error
            if error == nil && object == nil {
                error = HttpError.parsingFailed
            }
            completion(response, object, error)
        }
    }

    public func urlWithParameters(url: URL, parameters: [String: String]) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!

        if !parameters.isEmpty {
            let serializer = UrlEncodedHttpSerializer()
            var params = serializer.deserialize(components.query) ?? [:]
            parameters.forEach { key, value in
                params[key] = value
            }
            components.percentEncodedQuery = serializer.serialize(params)
        }

        return components.url!
    }

    public func request(
        method: String, url: URL, urlParameters: [String: String],
        headers: [String: String], body: Data?
    ) -> NSMutableURLRequest {
        let request = NSMutableURLRequest(url: urlWithParameters(url: url, parameters: urlParameters))
        request.httpMethod = method
        request.httpBody = body
        headers.forEach { name, value in
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    public func request(
        method: HttpMethod, url: URL, urlParameters: [String: String],
        headers: [String: String], body: Data?
    ) -> NSMutableURLRequest {
        return request(method: method.value, url: url, urlParameters: urlParameters, headers: headers, body: body)
    }

    public func request<T: HttpSerializer>(
        method: HttpMethod, url: URL, urlParameters: [String: String],
        headers: [String: String],
        object: T.Value?, serializer: T
    ) -> NSMutableURLRequest {
        let req = request(method: method, url: url, urlParameters: urlParameters,
            headers: headers, body: serializer.serialize(object))
        if req.httpBody != nil {
            req.setValue(serializer.contentType, forHTTPHeaderField: "Content-Type")
        }
        return req
    }
}