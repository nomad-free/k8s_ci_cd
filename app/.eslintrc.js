module.exports = {
  env: {
    node: true,
    es2021: true,
    jest: true,
  },
  extends: ["eslint:recommended"],
  parserOptions: {
    ecmaVersion: "latest",
    sourceType: "module",
  },
  rules: {
    "no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
    "no-console": "off",
    semi: ["error", "always"],
    // [수정] "off"로 설정하여 싱글/더블 쿼트 모두 허용 (에러 무시)
    quotes: "off",
  },
};
