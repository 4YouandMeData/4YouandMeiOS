import Foundation
import RxSwift
import Moya
#if !COCOAPODS
    import Moya_ModelMapper
#endif

public extension ObservableType where Element == Response {

    @available(*, unavailable, renamed: "map(to:keyPath:)")
    func mapObject<T: Mappable>(type: T.Type, keyPath: String? = nil) -> Observable<T> { fatalError() }

    @available(*, unavailable, renamed: "map(to:keyPath:)")
    func mapArray<T: Mappable>(type: T.Type, keyPath: String? = nil) -> Observable<[T]> { fatalError() }

    @available(*, unavailable, renamed: "mapOptional(to:keyPath:)")
    func mapObjectOptional<T: Mappable>(type: T.Type, keyPath: String? = nil) -> Observable<T?> { fatalError() }

    @available(*, unavailable, renamed: "mapOptional(to:keyPath:)")
    func mapArrayOptional<T: Mappable>(type: T.Type, keyPath: String? = nil) -> Observable<[T]?> { fatalError() }
}
