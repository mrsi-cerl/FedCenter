// @ts-check
import { defineConfig } from "astro/config";
import { loadEnv } from "vite";
import sitemap from "@astrojs/sitemap";

const env = loadEnv(
  // @ts-ignore
  process.env.NODE_ENV,
  process.cwd(),
  ""
);

// console.log("env: ", env);

export default defineConfig({
  // Required for the sitemap to generate.
  // Set FEDCENTER_SITE in your environment variables to the your localhost, usually http://localhost:4321
  site: env.FEDCENTER_SITE || "https://fedcenter.gov",

  integrations: [sitemap()],

  vite: {
    server: {
      watch: {
        ignored: ["**/_site/**/*"],
      },
    },
  },

  // This should allow us to remove the environment variable
  outDir: "./_site",
  publicDir: "./public",
  // to guarantee we aren't using any server-side rendering (SSR) - since we have no server
  output: "static",

  //use a different base depending on which branch we are using.
  //This area will need to be updated if we are to add another preview site
  base:
    env.BRANCH === "demo-branch"
      ? "demo/mrsi-cerl/fedcenter/"
      : "site/mrsi-cerl/fedcenter/", //this is the base on MASTER branch
});