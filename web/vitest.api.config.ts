import { defineConfig } from "vitest/config";

// Black-box API tests (web/test/api). They need a running API; see
// .github/workflows/api-tests.yml for how CI starts one.
export default defineConfig({
  test: {
    include: ["test/api/**/*.test.ts"],
    environment: "node",
    testTimeout: 15_000,
  },
});
