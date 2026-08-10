import Foundation

protocol AppActionHandlerRouting: AnyObject {
  var actions: AppActionHandlers { get }
}

/// Common routing shell. It intentionally contains no application Context;
/// concrete handlers retain only their feature dependency struct.
class AppActionHandler: AppActionHandlerRouting {
  weak var aggregate: AppActionHandlers?
  weak var documentLifecycleController: (any DocumentLifecycleControlling)?

  init() {}

  let unitLabel = "mm"

  var actions: AppActionHandlers {
    guard let aggregate else {
      preconditionFailure("Action handler aggregate is not connected")
    }
    return aggregate
  }

  static let defaultPatternLineStyleID = "style:outer-cut-line"
  static let patternLineStylePresetIDs = [
    "style:outer-cut-line",
    "style:stitch-line",
    "style:fold-line",
    "style:center-line",
    "style:construction-line",
    "style:dimension-line",
  ]
}

final class CanvasActionHandler: AppActionHandler, CanvasActionHandlerDependencyProviding {
  let handlerDependencies: CanvasActionHandlerDependencies

  init(dependencies: CanvasActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

final class DocumentActionHandler: AppActionHandler, DocumentActionHandlerDependencyProviding {
  let handlerDependencies: DocumentActionHandlerDependencies

  init(dependencies: DocumentActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

final class ConstraintActionHandler: AppActionHandler, ConstraintActionHandlerDependencyProviding {
  let handlerDependencies: ConstraintActionHandlerDependencies

  init(dependencies: ConstraintActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

final class InspectorActionHandler: AppActionHandler, InspectorActionHandlerDependencyProviding {
  let handlerDependencies: InspectorActionHandlerDependencies

  init(dependencies: InspectorActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

final class PartActionHandler: AppActionHandler, PartActionHandlerDependencyProviding {
  let handlerDependencies: PartActionHandlerDependencies

  init(dependencies: PartActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

final class OutputActionHandler: AppActionHandler, OutputActionHandlerDependencyProviding {
  let handlerDependencies: OutputActionHandlerDependencies

  init(dependencies: OutputActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

final class RecoveryActionHandler: AppActionHandler, RecoveryActionHandlerDependencyProviding {
  let handlerDependencies: RecoveryActionHandlerDependencies

  init(dependencies: RecoveryActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

final class WorkspaceActionHandler: AppActionHandler, WorkspaceActionHandlerDependencyProviding {
  let handlerDependencies: WorkspaceActionHandlerDependencies

  init(dependencies: WorkspaceActionHandlerDependencies) {
    handlerDependencies = dependencies
    super.init()
  }
}

/// Feature action aggregate owned by the application composition root.
final class AppActionHandlers {
  let document: DocumentActionHandler
  let canvas: CanvasActionHandler
  let constraints: ConstraintActionHandler
  let inspector: InspectorActionHandler
  let parts: PartActionHandler
  let output: OutputActionHandler
  let recovery: RecoveryActionHandler
  let workspace: WorkspaceActionHandler

  init(context: AppActionHandlerContext) {
    document = DocumentActionHandler(dependencies: context.documentActionHandlerDependencies)
    canvas = CanvasActionHandler(dependencies: context.canvasActionHandlerDependencies)
    constraints = ConstraintActionHandler(dependencies: context.constraintActionHandlerDependencies)
    inspector = InspectorActionHandler(dependencies: context.inspectorActionHandlerDependencies)
    parts = PartActionHandler(dependencies: context.partActionHandlerDependencies)
    output = OutputActionHandler(dependencies: context.outputActionHandlerDependencies)
    recovery = RecoveryActionHandler(dependencies: context.recoveryActionHandlerDependencies)
    workspace = WorkspaceActionHandler(dependencies: context.workspaceActionHandlerDependencies)

    document.aggregate = self
    canvas.aggregate = self
    constraints.aggregate = self
    inspector.aggregate = self
    parts.aggregate = self
    output.aggregate = self
    recovery.aggregate = self
    workspace.aggregate = self
  }
}
