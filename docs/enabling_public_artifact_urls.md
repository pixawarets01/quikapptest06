# How to Enable Public Artifact URLs in Codemagic

This guide explains how to resolve the `{"error":"FORBIDDEN"}` message when trying to download build artifacts from a URL provided in an email notification.

## The Problem

By default, Codemagic artifact URLs are private and require you to be logged into your Codemagic account to access them. This is a security feature to protect your builds. When you click a link from an email without being logged in, you will see a "FORBIDDEN" error.

Our build scripts are already configured to use public URLs, but they are only generated if you enable the feature in your Codemagic team settings.

## The Solution: Enable Build Dashboards

A Codemagic **team admin** must enable build dashboards to allow the generation of public-facing links for artifacts.

**Here are the steps:**

1.  **Log in to Codemagic** as a team admin.
2.  Navigate to your team by clicking **Teams** in the left sidebar and selecting your team.
3.  In the right panel, go to **Team settings**.
4.  Expand the **Build dashboards** section.
5.  Click the **Enable sharing** button.

![Enable Sharing](https://docs.codemagic.io/yaml-publishing/img/share-builds.png)

That's it! After you enable this setting, all subsequent builds will generate a `public_url` for each artifact, and the links in your email notifications will become publicly accessible without requiring a login.

### Alternative Solution (Advanced)

If you cannot enable Build Dashboards, an alternative is to use the Codemagic REST API to generate temporary public URLs during the build. This would require:

1.  Generating a Codemagic API token.
2.  Storing it as a secure environment variable (e.g., `CODEMAGIC_API_TOKEN`).
3.  Modifying the `lib/scripts/utils/process_artifacts.sh` script to make `curl` requests to the Artifacts API for each artifact to generate a public link.

This approach is more complex and is only recommended if the primary solution is not possible. Our current setup is designed for the simpler "Build dashboards" feature.
