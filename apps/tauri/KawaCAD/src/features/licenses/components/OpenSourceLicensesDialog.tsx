import { useEffect, useState } from "react";
import { thirdPartyLicenses, type ThirdPartyLicense } from "@/features/licenses/thirdPartyLicenses";

type OpenSourceLicensesDialogProps = {
  onClose: () => void;
};

export function OpenSourceLicensesDialog({ onClose }: OpenSourceLicensesDialogProps) {
  const [licenses, setLicenses] = useState<readonly ThirdPartyLicense[] | null>(null);

  useEffect(() => {
    let active = true;
    void fetch("./ThirdPartyNotices.json")
      .then((response) => (response.ok ? response.json() : undefined))
      .then((payload: { components?: ThirdPartyLicense[] } | undefined) => {
        if (!active) return;
        setLicenses(payload?.components?.length ? payload.components : thirdPartyLicenses);
      })
      .catch(() => {
        if (active) setLicenses(thirdPartyLicenses);
      });
    return () => {
      active = false;
    };
  }, []);

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <section
        className="licenses-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="open-source-licenses-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header className="licenses-dialog-header">
          <h2 id="open-source-licenses-title">OSSライセンス</h2>
          <button type="button" onClick={onClose} aria-label="閉じる">
            閉じる
          </button>
        </header>
        <div className="licenses-dialog-body" aria-busy={licenses === null}>
          {licenses === null ? (
            <p>読み込み中…</p>
          ) : (
            licenses.map((license) => (
              <article className="license-entry" key={`${license.name}-${license.license}`}>
                <h3>{license.name}</h3>
                <p>
                  {license.version} · {license.license}
                </p>
                {license.copyright && <p>{license.copyright}</p>}
                <pre>{license.text}</pre>
              </article>
            ))
          )}
        </div>
      </section>
    </div>
  );
}
