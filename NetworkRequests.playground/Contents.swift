import PlaygroundSupport
import UIKit

public extension Data {
    func toModel() -> Entry? {
        return try? JSONDecoder().decode(Entry.self, from: self)
    }

}

public protocol Model: Codable, Equatable {}

public extension Model {
    func toData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    func toJson() -> [String: Any]? {
        guard let data = self.toData() else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
    }
}

public struct Entry: Model {
    var thumbnailUrl: Data
    var url: Data
    
    public init(thumbnailUrl: Data, url: Data) {
        self.thumbnailUrl = thumbnailUrl
        self.url = url
    }
    
    public func toAddPhotoModel() -> Entry {
        return Entry(thumbnailUrl: thumbnailUrl, url: url)
    }
}

public struct Entry2: Model {
    var thumbnailUrl: Data
    var url: Data
    
    public init(thumbnailUrl: Data, url: Data) {
        self.thumbnailUrl = thumbnailUrl
        self.url = url
    }
    
    public func toAddPhotoModel() -> Entry {
        return Entry(thumbnailUrl: thumbnailUrl, url: url)
    }
}

public final class RemoteFeedImageDataLoader: FeedImageDataLoader {
    private let client: HTTPClient
    
    public init(client: HTTPClient) {
        self.client = client
    }
    
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    private final class HTTPClientTaskWrapper: FeedImageDataLoaderTask {
        private var completion: ((FeedImageDataLoader.ResultImage) -> Void)?
        
        var wrapped: HTTPClientTask?
        
        init(_ completion: @escaping (FeedImageDataLoader.ResultImage) -> Void) {
            self.completion = completion
        }
        
        func complete(with result: FeedImageDataLoader.ResultImage) {
            completion?(result)
        }
        
        func cancel() {
            preventFurtherCompletions()
            wrapped?.cancel()
        }
        
        private func preventFurtherCompletions() {
            completion = nil
        }
    }
    
    public func loadImageData(from url: URL, completion: @escaping (FeedImageDataLoader.ResultImage) -> Void) -> FeedImageDataLoaderTask {
        let task = HTTPClientTaskWrapper(completion)
        task.wrapped = client.get(from: url) { [weak self] result in
            guard self != nil else { return }
            
            task.complete(with: result
                .mapError { _ in Error.connectivity }
                .flatMap { (data, response) in
                    let isValidResponse = response.isOK && !data.isEmpty
                    return isValidResponse ? .success(Entry.init(thumbnailUrl: data, url: data)) : .failure(Error.invalidData)
            })
        }
        return task
    }
}

public protocol FeedImageDataLoaderTask {
    func cancel()
}

public protocol FeedImageDataLoader {
    //    typealias Result = Swift.Result<Data, Error>
    typealias ResultImage = Swift.Result<Entry, Error>
    
    func loadImageData(from url: URL, completion: @escaping (ResultImage) -> Void) -> FeedImageDataLoaderTask
}

public protocol HTTPClientTask {
    func cancel()
}

public protocol HTTPClient {
    typealias Result = Swift.Result<(Data, HTTPURLResponse), Error>
    
    /// The completion handler can be invoked in any thread.
    /// Clients are responsible to dispatch to appropriate threads, if needed.
    @discardableResult
    func get(from url: URL, completion: @escaping (Result) -> Void) -> HTTPClientTask
}

extension HTTPURLResponse {
    private static var OK_200: Int { return 200 }
    
    var isOK: Bool {
        return statusCode == HTTPURLResponse.OK_200
    }
}

public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    
    public init(session: URLSession) {
        self.session = session
    }
    
    private struct UnexpectedValuesRepresentation: Error {}
    
    private struct URLSessionTaskWrapper: HTTPClientTask {
        let wrapped: URLSessionTask
        
        func cancel() {
            wrapped.cancel()
        }
    }
    
    public func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> HTTPClientTask {
        let task = session.dataTask(with: url) { data, response, error in
            completion(Result {
                if let error = error {
                    throw error
                } else if let data = data, let response = response as? HTTPURLResponse {
                    return (data, response)
                } else {
                    throw UnexpectedValuesRepresentation()
                }
            })
        }
        task.resume()
        return URLSessionTaskWrapper(wrapped: task)
    }
}

public enum HttpError: Error {
    case noConnectivity
    case badRequest
    case serverError
    case unauthorized
    case forbidden
}


//URLSessionHTTPClient.get(URLSessionHTTPClient)
let url = URL(string: "https://jsonplaceholder.typicode.com/photos")
let url2 = URL(string: "https://via.placeholder.com/150/92c952")
let client = URLSessionHTTPClient(session: URLSession(configuration: .default))



let remoteFeed = RemoteFeedImageDataLoader(client: client)


URLSessionHTTPClient.get(client)
var received = [FeedImageDataLoader.ResultImage]()


let viewModel = Entry(thumbnailUrl: Data.init(), url: Data.init())

remoteFeed.loadImageData(from: url2!) { (result: Result<Entry, Error>) in
    
    switch result {
    case .success(let data):
        print(data.toAddPhotoModel())
        var test = UIImage(data: data.url)
        var test2 = UIImage(data: data.thumbnailUrl)
        print(test)
        print(result)
    case .failure:
        print(result)
    }
    
}
    

