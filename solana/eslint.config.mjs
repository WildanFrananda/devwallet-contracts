// @ts-check
import eslint from "@eslint/js"
import globals from "globals"
import tseslint from "typescript-eslint"

export default tseslint.config(
  {
    ignores: [
      "eslint.config.mjs",
      "node_modules/",
      "target/",
      ".anchor/",
      "**/*.d.ts"
    ]
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.mocha
      },
      ecmaVersion: "latest",
      sourceType: "module",
      parserOptions: {
        projectService: {
          allowDefaultProject: ["*.js", "*.mjs", "*.cjs"]
        },
        tsconfigRootDir: /** @type {any} */ (import.meta).dirname
      }
    }
  },
  {
    rules: {
      // Google style base rules
      "max-len": ["error", { code: 120, tabWidth: 2 }],
      "no-tabs": "error",
      indent: ["error", 2, { ignoredNodes: ["PropertyDefinition[decorators]"], "SwitchCase": 1 }],
      "no-mixed-spaces-and-tabs": "error",
      "no-trailing-spaces": "error",
      "linebreak-style": ["error", "unix"],
      "no-multiple-empty-lines": ["error", { max: 2 }],

      // Custom rules
      "new-cap": "off",
      "comma-dangle": ["error", "never"],
      quotes: ["error", "double", { allowTemplateLiterals: true }],
      semi: ["error", "never"],
      "@typescript-eslint/explicit-member-accessibility": "off",
      "object-curly-spacing": "off",
      camelcase: "off",
      "operator-linebreak": "off",
      "valid-jsdoc": "off",
      "require-jsdoc": "off",
      "quote-props": "off",

      // TypeScript rules
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-floating-promises": "warn",
      "@typescript-eslint/no-unsafe-argument": "warn",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/no-empty-object-type": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-member-access": "off"
    }
  },
  {
    files: ["**/*.spec.ts", "**/*.test.ts", "tests/**/*.ts"],
    rules: {
      "@typescript-eslint/unbound-method": "off",
      "@typescript-eslint/no-explicit-any": "off"
    }
  },
  {
    files: ["**/*.js", "**/*.cjs", "**/*.mjs"],
    rules: {
      "@typescript-eslint/no-require-imports": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-return": "off"
    }
  }
)
