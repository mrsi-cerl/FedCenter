// 1. Import utilities from `astro:content`
import { defineCollection } from "astro:content";

// 2. Import loader(s)
import { glob } from "astro/loaders";

// 3. Import Zod
import { z } from "astro/zod";

const categories = [
  "Regulations, Guidance, and Policy",
  "Supporting Information and Tools",
  "Lessons Learned",
  "Training, Presentations, and Briefings",
  "Conferences and Events",
] as const;

const subCategories = [
  "Executive Orders",
  "Laws, Regulations, and Agreements",
  "Guidance",
  "Databases and Software Tools",
  "Directories, Catalogs, and Newsletters",
  "Libraries and Repositories",
  "Organizations and Programs",
  "Award Winners",
  "Case Studies",
  "Contract and Procurement Language",
  "Purchasing Guides",
  "",
  "",
  "",
  "",
] as const;

// 4. Define a `loader` and `schema` for each collection
const programPost = defineCollection({
  loader: glob({ base: "./src/content/programs", pattern: "**/*.{md,mdx}" }),
  schema: z.object({
    programArea: z.string(),
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    category: z.enum(categories),
    subcategory: z.string(),
    // tags: []
    externalUrl: z.string().optional(),
  }),
});

const announcements = defineCollection({
  loader: glob({
    base: "./src/content/announcements",
    pattern: "**/*.{md,mdx}",
  }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    expiresOn: z.coerce.date(),
    // tags: []
    externalUrl: z.string().optional(),
  }),
});

export const collections = { programPost, announcements };
