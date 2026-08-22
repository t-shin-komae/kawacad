import type { ComponentReference as ComponentReferenceModel } from "./componentCatalog";

type Props = {
  reference: ComponentReferenceModel;
};

/** Documentation-only card for components that require a live Core snapshot or OS service. */
export function ComponentReference({ reference }: Props) {
  return (
    <article className="component-reference-card">
      <header>
        <p className="component-reference-kicker">
          {reference.area} · {reference.role}
        </p>
        <h1>{reference.name}</h1>
      </header>
      <p>{reference.summary}</p>
      <dl>
        <div>
          <dt>Input / display model</dt>
          <dd>{reference.inputs}</dd>
        </div>
        <div>
          <dt>Swift/macOS</dt>
          <dd>
            <code>{reference.swiftSource}</code>
          </dd>
        </div>
        <div>
          <dt>Tauri/React</dt>
          <dd>
            <code>{reference.tauriSource}</code>
          </dd>
        </div>
      </dl>
      <p className="component-reference-note">
        This page is a reference document and does not reimplement Core snapshots or OS APIs. See
        <code>InteractivePrimitives</code> for interactive examples of independent input components.
      </p>
    </article>
  );
}
