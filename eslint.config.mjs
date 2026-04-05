import js from "@eslint/js";
import globals from "globals";

// QML JS files begin with `.pragma library` which is not valid JS syntax.
// This processor strips that line before ESLint parses the file.
const stripQmlPragma = {
  preprocess(text) {
    return [text.replace(/^\.pragma\s+\S+[ \t]*(\r?\n|$)/mg, "")];
  },
  postprocess(messages) {
    return messages.flat();
  },
  supportsAutofix: true,
};

export default [
  // Ignore generated/third-party directories
  {
    ignores: ["node_modules/**", "tests/qml/mocks/**"],
  },

  // Qt V4 JS plugin scripts — no ES modules, var-based
  {
    files: ["scripts/**/*.js"],
    ...js.configs.recommended,
    processor: stripQmlPragma,
    languageOptions: {
      ecmaVersion: 5,
      sourceType: "script",
      globals: {
        // Qt/QML globals injected at runtime
        Qt: "readonly",
        console: "readonly",
        XMLHttpRequest: "readonly",
        QSettings: "readonly",
        iface: "readonly",
        // QGIS C++ API objects exposed to QML context
        qgisProject: "readonly",
        QgsDistanceArea: "readonly",
        QgsRectangle: "readonly",
        QgsGeometry: "readonly",
        GeometryUtils: "readonly",
        FeatureUtils: "readonly",
      },
    },
    rules: {
      // Qt V4 engine uses var — allow it without warnings
      "no-var": "off",
      // Top-level vars in .pragma library files are the public API called from QML
      "no-unused-vars": "off",
      // Warn on common bugs
      "no-undef": "warn",
      "eqeqeq": ["error", "always"],
      "no-eval": "error",
    },
  },

  // Jest test files — CommonJS, Node globals
  {
    files: ["tests/js/**/*.js"],
    ...js.configs.recommended,
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "commonjs",
      globals: {
        ...globals.node,
        ...globals.jest,
      },
    },
    rules: {
      "no-unused-vars": ["warn", { args: "none" }],
    },
  },
];