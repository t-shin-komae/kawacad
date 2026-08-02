import CoreGraphics
import Foundation
import KawaCADOutput

/// Explicit dependency bundle for feature actions.
///
/// It contains references to state owners and adapters, but never to the
/// composition root. Action handlers can therefore be constructed and tested
/// without an `AppCoordinator` instance.
struct AppActionHandlerContext {
  let cadSession: CadSessionState
  let canvasPresentation: CanvasPresentationState
  let documentPresentation: DocumentPresentationState
  let errorPresentationState: AppErrorPresentationState
  let inspectorPresentation: InspectorPresentationState
  let outputPresentation: OutputPresentationState
  let recoverySnapshotState: RecoverySnapshotState
  let workspacePreferences: WorkspacePreferencesState
  let workspaceLayout: WorkspaceLayoutState
  let partLibraryState: PartLibraryState
  let commandFactory: DocumentCommandFactory
  let desktopEnvironment: any DesktopEnvironmentAdapting

}
