export type DocumentHeaderHandle = {
  commit: () => Promise<boolean>;
  validate: () => boolean;
};
