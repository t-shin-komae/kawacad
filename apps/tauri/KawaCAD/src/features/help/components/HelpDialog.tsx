import { useEffect, useMemo, useState } from "react";
import { appStrings } from "@/localization";
import type { HelpSection } from "@/features/help/state/useHelpPresentation";

type Props = {
  initialSection: HelpSection;
  onClose: () => void;
};

const sections: ReadonlyArray<{ id: HelpSection; label: string }> = [
  { id: "overview", label: appStrings.help.section.overview },
  { id: "tools", label: appStrings.help.section.tools },
  { id: "canvas", label: appStrings.help.section.canvas },
];

const shortcutRows = [
  ["⌘/Ctrl + 1〜5", appStrings.help.shortcut.tools],
  ["⌘/Ctrl + Z", appStrings.help.shortcut.undo],
  ["⌘/Ctrl + Shift + Z", appStrings.help.shortcut.redo],
  ["⌘/Ctrl + S", appStrings.help.shortcut.save],
  ["Esc", appStrings.help.shortcut.cancel],
] as const;

function HelpOverview() {
  return (
    <section className="help-section" aria-labelledby="help-overview-heading">
      <h3 id="help-overview-heading">{appStrings.help.basic.title}</h3>
      <p>{appStrings.help.basic.body}</p>
      <ul>
        <li>{appStrings.help.basic.cancel}</li>
        <li>{appStrings.help.basic.inspector}</li>
        <li>{appStrings.help.basic.editMenu}</li>
        <li>{appStrings.help.basic.viewMenu}</li>
      </ul>
    </section>
  );
}

function HelpTools({ query }: { query: string }) {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  const tools = useMemo(
    () =>
      (Object.keys(appStrings.toolNames) as Array<keyof typeof appStrings.toolNames>)
        .map((id) => ({ id, name: appStrings.toolNames[id], hint: appStrings.toolHints[id] }))
        .filter(({ name, hint }) => `${name} ${hint}`.toLocaleLowerCase().includes(normalizedQuery)),
    [normalizedQuery],
  );

  return (
    <section className="help-section" aria-labelledby="help-tools-heading">
      <h3 id="help-tools-heading">{appStrings.help.tools.title}</h3>
      <table className="help-shortcuts">
        <tbody>
          {shortcutRows.map(([shortcut, description]) => (
            <tr key={shortcut}>
              <th scope="row">{shortcut}</th>
              <td>{description}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <h4>{appStrings.help.tools.list}</h4>
      <dl className="help-tool-list">
        {tools.map(({ id, name, hint }) => (
          <div key={id}>
            <dt>{name}</dt>
            <dd>{hint}</dd>
          </div>
        ))}
      </dl>
      {!tools.length && <p>{appStrings.help.search.empty}</p>}
    </section>
  );
}

function HelpCanvas() {
  return (
    <section className="help-section" aria-labelledby="help-canvas-heading">
      <h3 id="help-canvas-heading">{appStrings.help.canvas.title}</h3>
      <ul>
        <li>{appStrings.help.canvas.gridSnap}</li>
        <li>{appStrings.help.canvas.pointSnap}</li>
        <li>{appStrings.help.canvas.controlSnap}</li>
        <li>{appStrings.help.canvas.marquee}</li>
        <li>{appStrings.help.canvas.optionDuplicate}</li>
        <li>{appStrings.help.canvas.displayAids}</li>
      </ul>
    </section>
  );
}

export function HelpDialog({ initialSection, onClose }: Props) {
  const [section, setSection] = useState(initialSection);
  const [query, setQuery] = useState("");

  useEffect(() => setSection(initialSection), [initialSection]);

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <section
        className="help-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="help-dialog-title"
        onMouseDown={(event) => event.stopPropagation()}
        onKeyDown={(event) => {
          if (event.key === "Escape") {
            event.preventDefault();
            event.stopPropagation();
            onClose();
          }
        }}
      >
        <header className="help-dialog-header">
          <div>
            <h2 id="help-dialog-title">{appStrings.help.title}</h2>
            <p>{appStrings.help.subtitle}</p>
          </div>
          <button type="button" onClick={onClose} aria-label={appStrings.common.close}>
            {appStrings.common.close}
          </button>
        </header>
        <nav className="help-dialog-nav" aria-label={appStrings.help.sectionPicker}>
          {sections.map((item) => (
            <button
              key={item.id}
              type="button"
              className={section === item.id ? "active" : ""}
              aria-current={section === item.id ? "page" : undefined}
              onClick={() => setSection(item.id)}
            >
              {item.label}
            </button>
          ))}
        </nav>
        {section === "tools" && (
          <label className="help-search">
            {appStrings.help.search.label}
            <input value={query} onChange={(event) => setQuery(event.target.value)} />
          </label>
        )}
        <div className="help-dialog-body">
          {section === "overview" && <HelpOverview />}
          {section === "tools" && <HelpTools query={query} />}
          {section === "canvas" && <HelpCanvas />}
        </div>
      </section>
    </div>
  );
}
