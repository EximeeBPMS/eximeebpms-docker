# GitHub Actions

There are three separate workflows, which are as follows:

1. [Build, test, and publish CE](./build-test-and-publish-ce.yml) - manually triggered (`workflow_dispatch`, with a required `VERSION` input) to build, test, and publish the CE image for both environments (`run`, `tomcat`) to GitHub Container Registry (GHCR).
2. [Sign published CE images](./sign-ce.yml) - manually triggered (`workflow_dispatch`, with a required `TAGS` input) to sign images that are already on GHCR, without rebuilding or moving any tag. Used for the images published before the publish workflow signed them; the publish workflow itself signs each image it publishes, keylessly with cosign (GitHub Actions OIDC).
3. [Slack Notifications](./slack.yml) - posts a message to Slack on a wide range of repository events (pushes, PRs, issues, releases, discussions, failed workflow runs, etc.).
