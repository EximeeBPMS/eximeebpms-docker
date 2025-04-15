# GitHub Actions

There are two separate workflows, which are as follows:

1. [Build, test, and publish CE](./build-test-and-publish-ce.yml) - run on every push and PR to check CE image (public) for all 3 environments (tomcat, wildfly, run). Additionally, it publishes the image on new commits to next and 7.x branches to Docker Hub.
