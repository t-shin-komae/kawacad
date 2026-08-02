import Foundation

enum AppErrorCategory: String, Hashable {
  case userCorrectable
  case operationFailure
  case systemInternal

  var title: String {
    switch self {
    case .userCorrectable:
      return AppStrings.tr("error.category.user_correctable")
    case .operationFailure:
      return AppStrings.tr("error.category.operation_failure")
    case .systemInternal:
      return AppStrings.tr("error.category.system_internal")
    }
  }

}

struct AppErrorIdentity: Hashable {
  let category: AppErrorCategory
  let code: String
  let operation: String
  let commandKind: String?
  let constraintKind: String?
  let targetIDs: [String]
}

struct AppErrorPresentation: Identifiable, Hashable {
  let identity: AppErrorIdentity
  let message: String
  let details: String?
  let recoverySuggestion: String?
  var occurrenceCount: Int

  var id: String {
    [
      identity.category.rawValue,
      identity.code,
      identity.operation,
      identity.commandKind ?? "",
      identity.constraintKind ?? "",
      identity.targetIDs.joined(separator: ","),
    ].joined(separator: "|")
  }
}

extension AppErrorPresentation {
  static func coreFailure(
    _ failure: CoreFailure,
    operation: String,
    commandKind: String? = nil
  ) -> AppErrorPresentation {
    let details = failure.details?.objectValue ?? [:]
    return make(
      category: .operationFailure,
      code: failure.code,
      operation: operation,
      message: failure.localizedDescription,
      details: failure.message,
      commandKind: commandKind ?? details["commandKind"]?.stringValue,
      constraintKind: details["constraintKind"]?.stringValue,
      targetIDs: details["targetIds"]?.stringArrayValue ?? []
    )
  }

  static func make(
    category: AppErrorCategory,
    code: String,
    operation: String,
    message: String,
    details: String? = nil,
    recoverySuggestion: String? = nil,
    commandKind: String? = nil,
    constraintKind: String? = nil,
    targetIDs: [String] = []
  ) -> AppErrorPresentation {
    AppErrorPresentation(
      identity: AppErrorIdentity(
        category: category,
        code: code,
        operation: operation,
        commandKind: commandKind,
        constraintKind: constraintKind,
        targetIDs: targetIDs.sorted()
      ),
      message: message,
      details: details,
      recoverySuggestion: recoverySuggestion,
      occurrenceCount: 1
    )
  }
}
