export type ThirdPartyLicense = {
  name: string;
  version: string;
  license: string;
  source?: string;
  copyright?: string;
  text: string;
};

// Release builds replace this fallback by running the generator first.
export const thirdPartyLicenses: readonly ThirdPartyLicense[] = [
  {
    name: "lucide-react",
    version: "1.26.0",
    license: "ISC",
    text: `Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES.`,
  },
  {
    name: "lucide-react (Feather-derived icons)",
    version: "1.26.0",
    license: "MIT",
    text: `Copyright (c) 2013-present Cole Bemis

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.`,
  },
];
