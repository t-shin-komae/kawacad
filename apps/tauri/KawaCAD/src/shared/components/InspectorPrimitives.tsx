import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";

export function InspectorSection({
  title,
  icon: Icon,
  className,
  children,
}: {
  title: string;
  icon: LucideIcon;
  className?: string;
  children: ReactNode;
}) {
  return (
    <section className={["inspector-section", className].filter(Boolean).join(" ")}>
      <h2>
        <Icon aria-hidden="true" />
        {title}
      </h2>
      <div className="inspector-section-content">{children}</div>
    </section>
  );
}

export function InspectorDisclosureRow({
  title,
  subtitle,
  metadata,
  expanded,
  onToggle,
  children,
}: {
  title: string;
  subtitle: string;
  metadata: string;
  expanded: boolean;
  onToggle: () => void;
  children: ReactNode;
}) {
  return (
    <div className="inspector-disclosure">
      <button
        type="button"
        className={`inspector-disclosure-summary${expanded ? " selected" : ""}`}
        aria-expanded={expanded}
        onClick={onToggle}
      >
        <span>
          <strong>{title}</strong>
          <small>{subtitle}</small>
        </span>
        <small>{metadata}</small>
      </button>
      {expanded && <div className="inspector-disclosure-content">{children}</div>}
    </div>
  );
}
