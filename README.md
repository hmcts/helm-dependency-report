## helm-dependency-report

This repo contains a shell script and a github action workflow. The github action will run the script and return a list of pull requests across the organisation that were raised by [renovatebot](https://github.com/renovatebot/renovate) which relate to helm chart dependencies.

Only repositories that have pull requests that were created 7 days ago or more will be returned.

A slack notification will be sent detailing the pull requests that are pending review.