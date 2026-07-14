// @ts-check
import { defineConfig } from "astro/config";

import { loadEnv } from "vite";

const env = loadEnv(
  // @ts-ignore
  process.env.NODE_ENV,
  process.cwd(),
  ""
);

console.log("env: ", env);

export default defineConfig({
  // when deployed for real
  // site: 'https://fedcenter.gov

  // This should allow us to remove the environment variable
  outDir: "./_site",
  publicDir: "./public",
  // to guarantee we aren't using any server-side rendering (SSR) - since we have no server
  output: "static",
  // base: process.env.BASE_PATH || "site/mrsi-cerl/fedcenter/",
  // Ensure BASE_URL always ends with / so ${base}asset paths join correctly
  base:
    env.BRANCH === "demo-branch"
      ? "demo/mrsi-cerl/fedcenter/"
      : "site/mrsi-cerl/fedcenter/",
  // site: process.env.SITE || "http://localhost:4321",
  // // site: "site/mrsi-cerl/fedcenter/"

  // base: "site/mrsi-cerl/fedcenter/",
});
