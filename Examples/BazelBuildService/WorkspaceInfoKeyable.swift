import XCBProtocol

protocol WorkspaceInfoKeyable {
    var workspaceName: String { get }
    var workspaceHash: String { get }
    var workspaceKey: String { get }
}

extension WorkspaceInfoKeyable {
    var workspaceKey: String { WorkspaceInfo.workspaceKey(workspaceName: self.workspaceName, workspaceHash: self.workspaceHash) }
}

extension CreateSessionRequest: WorkspaceInfoKeyable {}
extension CreateBuildRequest: WorkspaceInfoKeyable {}
extension IndexingInfoRequested: WorkspaceInfoKeyable {}