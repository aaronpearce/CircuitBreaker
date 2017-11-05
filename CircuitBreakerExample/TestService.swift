import Foundation

public class TestService {
    
    public typealias CompletionBlock = (Data?, Error?) -> Void
    
    public func successCall(completion: @escaping CompletionBlock) {
        makeCall("get", completion: completion)
    }
    
    public func failureCall(completion: @escaping CompletionBlock) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            completion(nil, NSError(domain: "TestService", code: 404, userInfo: nil))
        }
    }
    
    public func delayedCall(_ delayInSeconds: Int, completion: @escaping CompletionBlock) {
        makeCall("delay/\(delayInSeconds)", completion: completion)
    }
    
    private func makeCall(_ path: String, completion: @escaping CompletionBlock) {
        let task = URLSession.shared.dataTask(with: URL(string: "https://httpbin.org/\(path)")!) { data, response, error in
            DispatchQueue.main.async() {
                completion(data, error)
            }
        }
        task.resume()
    }
    
}
