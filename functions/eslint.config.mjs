module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json"], // ✅ On ne garde que le tsconfig.json principal
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore les fichiers JavaScript compilés
  ],
  plugins: ["@typescript-eslint", "import"],
  rules: {
    "quotes": ["error", "double"],
    "max-len": "off",             // ✅ On désactive la vérification de la longueur des lignes
    "require-jsdoc": "off",       // ✅ On désactive l'obligation de commenter chaque fonction
    "valid-jsdoc": "off",
    "indent": "off",              // On désactive la règle d'indentation
    "camelcase": "off",           // On désactive la vérification du camelCase pour les clés d'API
    "object-curly-spacing": ["error", "always"],
  },
};