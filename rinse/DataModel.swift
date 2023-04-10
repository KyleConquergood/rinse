//
//  DataModel.swift
//  rinse
//
//  Created by kyle on 2023-04-09.
//

import Foundation

class DataModel: ObservableObject {
    @Published var logs: [Log] = []

    func addLog(log: Log) {
        logs.append(log)
    }
}

struct Log: Identifiable {
    let id = UUID()
    let timestamp: Int
    let source: String
}
