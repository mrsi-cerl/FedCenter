// @ts-check
import { defineConfig } from "astro/config";

export default defineConfig({
  // when deployed for real
  // site: 'https://fedcenter.gov

  // This should allow us to remove the environment variable
  outDir: "./_site",
  publicDir: "./public",
  // to guarantee we aren't using any server-side rendering (SSR) - since we have no server
  output: "static",
  base: "site/mrsi-cerl/fedcenter/",
});
