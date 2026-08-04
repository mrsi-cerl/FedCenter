// 1. Import utilities from `astro:content`
import { defineCollection } from "astro:content";

// 2. Import loader(s)
import { glob } from "astro/loaders";

// 3. Import Zod
import { z } from "astro/zod";

const programs = [
  "Acquisition",
  "Chemical",
  "Cleanup",
  "Climate Resilience",
  "Cultural Resources",
  "Electronics Stewardship",
  "EMS",
  "Energy",
  "Env. Compliance",
  "Greenhouse Gases",
  "High Performance Buildings",
  "Natural Resources",
  "NEPA",
  "PFAS",
  "Pollution Prevention",
  "Sustainability",
  "Transportation",
  "Water Efficiency",
];

//these categories are consistent across all programs
const categories = [
  "Regulations, Guidance, and Policy",
  "Supporting Information and Tools",
  "Lessons Learned",
  "Training, Presentations, and Briefings",
  "Conferences and Events",
] as const;

//these subCategories are NOT consistent across programs.
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
  // schema: z.object({
  //   programArea: z.array(z.enum(programs)), //any given item can exist on multiple programs
  //   title: z.string(),
  //   description: z.optional(z.string()),
  //   pubDate: z.date(),
  //   category: z.array(z.enum(categories)), //an item can exist on multiple categories? TODO: can it?
  //   subcategory: z.array(z.enum(subCategories)), //an item can exist on multiple subcategories? TODO: can it?
  //   // tags: []
  //   externalUrl: z.string().optional(),
  // }),
});

const announcements = defineCollection({
  loader: glob({
    base: "./src/content/announcements",
    pattern: "**/*.{md,mdx}",
  }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.date(),
    expiresOn: z.date(),
    // tags: []
    externalUrl: z.string().optional(),
  }),
});

const events = defineCollection({
  loader: glob({
    base: './src/content/programs',
    pattern: '**/*.{md,mdx}',
  }),
  schema: z.object({
    title: z.string(),
    pubDate: z.coerce.date(),
    startDate: z.coerce.date(),
    endDate: z.coerce.date(),
    eventType: z
      .enum(['Conference', 'Meeting', 'Training', 'Other']),
    // tags: []
    externalUrl: z.string().optional(),
  }),
});

export const collections = { programPost, announcements, events };
