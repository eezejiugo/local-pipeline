# Local-Pipeline
This script is used to simplify the deployment to `development` and `staging` environments.

### Setup
This is a one time setup, but first before you kick off your setup, it is recommended you read the DevOps prepared document on deploying to lower environments. This will first help you setup your local machine ready, and also provide you with deep understanding of what the scripting is doing at each stage and also help you contribute to the project.

Here is the document: [Deploying to lower environment](https://neonomics.atlassian.net/wiki/spaces/NPO/pages/4636180496/Suggestions+on+how+to+deploy+to+lower+environments)

### Deploying with local pipeline script
As mentioned above, the script helps us simplify the deployment process. Before running the script, ensure you have ran the commands:

[x] gcloud auth login

[x] gcloud auth application-default login

To ensure everything works smoothly while using the script, we need to add some configurations in our `helm-values-staging.yaml` or `helm-values-development.yaml` file (depending on the environment you are deploying to).

Example:
```yaml
image:
  repository: europe-west3-docker.pkg.dev/development-xxx11/docker-repository
  name: uapi
  tag: release-bulk-payment-SNAPSHOT
  pullPolicy: Always
  pullSecrets: gar-docker-credentials

label:
  app: uapi

podExtraLabels: {
  appName: "uapi",
  version: "release-bulk-payment-SNAPSHOT",
  stage: "stable",
  tier: "backend",
  owner: "neonomics",
  environment: "development"
}

podAnnotations: {
  deployment-date: "",
  build-id: "",
  commit-hash: "",
  namespace: "uapi",
  release-name: "uapi-v1"
}
```

Note that extra parameters `namespace` and `release-name` were added under the *podAnnotations*. Also, when running the script, you will noticed that `image.tag` and the `podExtraLabels.version` will be overwritten and replace by your branch name + timestamp + SNAPSHOT. The timestamp helps with redeploying your app after a change is done.

- namespace: is the kubectl namespace
- release-name: is the kubectl pod release-name

To run the script: `sh ./local-deployment.sh` for MacOS or `bash ./local-deployment.sh` for Windows

### NB:
This script can only be used to push maven library to the Google Artifact Registry, and for the deployment of Egress, Connectors, UAPI and Consent Manager.