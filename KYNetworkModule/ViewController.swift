//
//  ViewController.swift
//  KYNetworkModule
//
//  Created by keyon on 2022/9/4.
//

import UIKit

extension String {
    var URLEscaped: String {
       return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
}

struct JYGitHubSearchModel: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [JYGitHubSearchItemModel]

    private enum CodingKeys : String, CodingKey {
        case totalCount = "total_count", incompleteResults = "incomplete_results", items
    }
}

struct JYGitHubSearchItemModel: Codable {
    let id: Int
    let nodeId: String
    let name: String
    let fullName: String
    let isPrivate: Bool
    let description: String
    let url: String

    private enum CodingKeys : String, CodingKey {
        case id, nodeId = "node_id", name, fullName = "full_name" , isPrivate = "private", description, url
    }
}

class ViewController: UIViewController {

    private lazy var apiClient: KYAPIClient = {
        let apiClient = KYAPIClient(configuration: KYAPIClient.Configuration.init(baseURL: URL(string: "https://api.github.com"), sessionConfiguration: .default, delegate: JYAPIClientDelegate()))
        return apiClient
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        Task.detached {
            do {
                let model = try await self.apiClient.send(KYRequest<JYGitHubSearchModel>(method: .get, url: "/search/repositories", query: [("q", "RxSwift".URLEscaped)]))
                debugPrint(model.value) 
            } catch {
                debugPrint(error)
            }
        }

    }


}

