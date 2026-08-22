export const recoveryCandidates = [
  {
    id: "recoverable-1",
    displayName: "カードケース",
    originalDocumentPath: "/projects/card-case.kawa",
    updatedAtMs: 1_786_582_800_000,
    status: "recoverable",
  },
  {
    id: "broken-1",
    displayName: "破損した復旧候補",
    updatedAtMs: 1_786_582_200_000,
    status: "broken",
    details: "snapshot.kawa を読み込めません。",
  },
];

export const preparedPDF = {
  outputDocumentModel: {
    paperSize: "a4",
    orientation: "portrait",
    scale: "actualSize",
    pageCount: 1,
    pages: [
      {
        gridColumn: 0,
        gridRow: 0,
        widthMm: 210,
        heightMm: 297,
        rotationDeg: 0,
        printableAreaMm: { leftMm: -100, rightMm: 100, topMm: 143.5, bottomMm: -143.5 },
        graphics: [
          {
            geometry: {
              kind: "lineSegment",
              payload: { startMm: { xMm: -35, yMm: -45 }, endMm: { xMm: 35, yMm: -45 } },
            },
            style: {
              stroke: { red: 0, green: 0, blue: 0, alpha: 1 },
              strokeWidthMm: 0.2,
              pattern: "solid",
            },
          },
          {
            geometry: { kind: "circle", payload: { centerMm: { xMm: 0, yMm: 15 }, radiusMm: 24 } },
            style: {
              stroke: { red: 0.05, green: 0.32, blue: 0.78, alpha: 1 },
              strokeWidthMm: 0.35,
              pattern: "dashed",
            },
          },
        ],
        texts: [{ content: "型紙プレビュー", positionMm: { xMm: 0, yMm: 55 }, fontSizeMm: 4 }],
        guide: {
          startMm: { xMm: -90, yMm: -130 },
          endMm: { xMm: -40, yMm: -130 },
          label: "50mm",
          labelPositionMm: { xMm: -65, yMm: -125 },
        },
      },
    ],
  },
  warnings: [{ kind: "pageBoundaryCrossing", message: "ページ境界をまたぐ形状があります。" }],
};
