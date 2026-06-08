import nextVitals from "eslint-config-next/core-web-vitals";
import nextTypescript from "eslint-config-next/typescript";

const eslintConfig = [
  {
    ignores: [".next/**", "node_modules/**", "next-env.d.ts", "playwright-report/**", "test-results/**", "e2e/__artifacts__/**"]
  },
  ...nextVitals,
  ...nextTypescript
];

export default eslintConfig;
