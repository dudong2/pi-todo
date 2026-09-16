import Foundation

public struct Todo: Identifiable, Equatable, Sendable {
  public let id: String
  public let project: String
  public let title: String
  public let details: String
  public let createdAt: Date
  public let completedAt: Date?

  public init(
    id: String,
    project: String,
    title: String,
    details: String,
    createdAt: Date,
    completedAt: Date?
  ) {
    self.id = id
    self.project = project
    self.title = title
    self.details = details
    self.createdAt = createdAt
    self.completedAt = completedAt
  }
}
