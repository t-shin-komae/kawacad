import type { Preview } from "@storybook/react-vite";
import "../src/app/styles.css";

const preview: Preview = {
  parameters: {
    layout: "fullscreen",
    controls: { expanded: true },
    backgrounds: {
      default: "window",
      values: [{ name: "window", value: "#f5f5f7" }],
    },
  },
  decorators: [
    (Story) => (
      <div style={{ minHeight: "100vh", padding: 24, background: "var(--window)" }}>
        <Story />
      </div>
    ),
  ],
};

export default preview;
