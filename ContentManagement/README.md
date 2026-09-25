# FedCenter Content Management

We've chosen to store FedCenter content as [Markdown](https://www.markdownguide.org/) files. Markdown is mostly plain text, making it human-readable and easy to write. It supports simple formatting, like bold and italics, as well as tables, links, and more.

At the top of our Markdown file we can specify data about our content. This section of the file is called _FrontMatter_. We use this data to organize the content within the website.

Here's an example of some FrontMatter:

```
---
item_id: "41442"
title: 889 Representations Search
expiryDate: null
externalUrl: https://889.smartpay.gsa.gov/#/
programArea: Acquisition
publishDate: 10/5/2023
subCategory:
  - Databases and Software Tools
---

```

Note that it is surrounded by `---` at the top and bottom. FrontMatter uses the YAML specification which supports key-value pairs, lists, and nested structures.

## Content Repository

Content is now stored in a version-controlled repository called `Git`. Traditionally, this system was used by software developers to store code. In a sense, our content files can also be considered code since it's used to build the website along with the actual code files.

By keeping the content with the code, our repository knows when the site changes and can be scheduled to automatically update, keeping our site current with all changes.

### Git

Using Git can be complicated as it supports many different methods of managing code. We're going to abstract most of this away from FedCenter, but under the hood these concepts still apply.

While you will not use them directly, it's import to understand broadly what is happening.

### Working in Repositories

Git is considered a distributed version control system. Each user has their own copy of the repository, complete with all historical versions of every file that's been part of the repository. The authoritative repository is stored in a cloud environment, GitHub.

When you create or edit content, you will do it on your local computer. Then when your work is done, you'll _commit_ your changes to your _local_ repository. And when all local changes are complete, you'll _push_ those changes to the authoritative repository on GitHub. GitHub lets Cloud.gov know changes were made so Cloud.gov can grab those changes and rebuild the website, deploying it automatically when done.

Since everyone has a local copy of the repository, it's important to synchronize your repository before you start making changes. We don't want one person's changes to inadvertantly overwrite another's changes.

To simplify this process for non-develpers, we've incorporated most of the Git processes into the Create- and Edit- scripts. The scripts should synchronize your local repository when starting up and provide buttons to publish content back to the authoritative repository.

## Powershell Module and Scripts

### Why Powershell?

Without a server-hosted Content Management System (CMS), we needed a way for Content Editors create FedCenter content. Since content is file-based, we could just create a new file, but that wouldn't be convenient, nor would it guarantee consistency. You'd have to manually create the YAML FrontMatter variables, which is not only tedious, but also error prone.

Powershell scripts let us create an "application" that runs locally and doesn't require any special persmission or authorization from ACE-IT to run on your computer. And as an application, we can "template" the FrontMatter and only let you choose the right values (areas and sub-categories). Data organization can be strictly controlled.

### Content Management Module

The module is used to share functions with the scripts. This includes all the Git repository functions, plus other common functions like searching content and logging. This keeps us from duplicating code unnecessarily and reduces errors.

### Scripts

The main script provides a menu to synchronize, create, edit, and publish content. You only have to know how to open the menu and everything is can be controlled there.

### Tests

PowerShell testing is done primarily with Pester, the official test and mock framework for PowerShell, using `.Tests.ps1` files, `Describe`/`It` blocks, and `Invoke-Pester` to run tests.

#### What Pester Is

- Pester is the standard testing and mocking framework for PowerShell.
- Supports unit tests, integration tests, mocking, code coverage, and CI pipelines.
- Uses a behavior‑driven DSL: Describe, Context, It, Should, Mock.

#### Installing Pester

```
Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser
Import-Module Pester -Force
```

#### Invoking Pester to Run Tests

`Invoke-Pester -Path ./ContentManagement/Tests`

or you can Right-Click the test file and choose `Run Pester Tests`
