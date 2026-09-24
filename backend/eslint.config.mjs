import convexPlugin from "@convex-dev/eslint-plugin";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["convex/_generated/**", "node_modules/**", "*.config.*"] },
  ...tseslint.configs.recommended,
  ...convexPlugin.configs.recommended,
  {
    files: ["convex/**/*.ts"],
    languageOptions: {
      parserOptions: { project: "./convex/tsconfig.json", tsconfigRootDir: import.meta.dirname },
    },
    rules: {
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/no-non-null-assertion": "off",
      // Typed env declarations in convex.config.ts aren't supported by convex-test yet.
      "@convex-dev/no-process-env": "off",
    },
  },
);
