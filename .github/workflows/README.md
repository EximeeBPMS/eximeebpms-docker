# GitHub Actions

There are two separate workflows, which are as follows:

1. [Build, test, and publish CE](./build-test-and-publish-ce.yml) - manually triggered (`workflow_dispatch`, with a required `VERSION` input) to build, test, and publish the CE image for both environments (`run`, `tomcat`) to GitHub Container Registry (GHCR).
2. [Slack Notifications](./slack.yml) - posts a message to Slack on a wide range of repository events (pushes, PRs, issues, releases, discussions, failed workflow runs, etc.).
