# Local-Pipeline
This script is used to simplify the deployment to `development` and `staging` environments.

### Setup
This is a one time setup, but first before you kick off your setup, it is recommended you read the DevOps prepared document on deploying to lower environments. This will first help you setup your local machine ready, and also provide you with deep understanding of what the scripting is doing at each stage and also help you contribute to the project.

Here is the document: [Deploying to lower environment](https://neonomics.atlassian.net/wiki/spaces/NPO/pages/4636180496/Suggestions+on+how+to+deploy+to+lower+environments)

1. Clone the [Helm repository project](https://github.com/fintechinnovationas/helm-repository.git) from Github and store in your desired path.
2. Navigate to the folder `/helm-repository/stable/` in the clone helm project and get the path.
3. Run the command `pwd` to get the path to the working directory.
4. Replace the path `/Path/to/helm-repository/stable/` in the script with the path to your helm repository project from No.3 above.


### Deploying with local pipeline script
As mentioned above, the script helps us simplify the deployment process. Before running the script, ensure you have ran the commands:

[x] gcloud auth login

[x] gcloud auth application-default login

To run the script: `sh ./local-deployment.sh`