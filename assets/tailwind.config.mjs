import tailwindcssAnimate from "tailwindcss-animate";

// Tailwind config for sonic.
//
// Theme copied verbatim from seastar-app's tailwind.config.ts so the design
// tokens are identical — matching the original is the requirement, and every
// token that drifts here is a visual difference nobody asked for.
//
// The only change is `content`: Tailwind scans for class names, and ours live
// in .gleam files rather than .tsx.

/** @type {import('tailwindcss').Config} */
export default {
  // Paths are resolved from this file's directory, so the project sources are
  // one level up. Pointing at "./src" silently matched nothing and produced a
  // stylesheet with none of the app's classes in it — the page rendered
  // unstyled while every build reported success.
  content: ["../src/**/*.gleam"],
  theme: {
    extend: {
      screens: {
        xs: { min: "374px" },
      },
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
        primary: "hsl(var(--primary))",
        "primary-foreground": "hsl(var(--primary-foreground))",
        secondary: "var(--secondary)",
        "secondary-foreground": "var(--secondary-foreground)",
        special: "var(--special)",
        "special-foreground": "var(--special-foreground)",
        destructive: "hsl(var(--destructive))",
        "destructive-foreground": "hsl(var(--destructive-foreground))",
      },
    },
  },
  plugins: [tailwindcssAnimate],
};
