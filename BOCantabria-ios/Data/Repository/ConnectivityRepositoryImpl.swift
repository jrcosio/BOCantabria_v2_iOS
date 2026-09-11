//
//  ConnectivityRepositoryImpl.swift
//  Hands the domain the device's network path, without the domain seeing the platform.
//

struct ConnectivityRepositoryImpl: ConnectivityRepository {
    private let dataSource: ConnectivityDataSource

    init(dataSource: ConnectivityDataSource) {
        self.dataSource = dataSource
    }

    func isOnline() async -> Bool {
        await dataSource.isOnline()
    }
}
