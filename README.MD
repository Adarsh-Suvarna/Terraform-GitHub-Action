# Automate Terraform with GitHub Actions

GitHub Actions add continuous integration to GitHub repositories to automate the software builds, tests, and deployments. Automating Terraform with CI/CD enforces configuration best practices, promotes collaboration and automates the Terraform workflow.
In this repository we will explore managing infrastructure with Terraform and GitHub actions. Terraform has become the standard nowadays in managing Infrastructure as Code, while GitHub Actions is a continuous integration and delivery (CI/CD) platform integrated into GitHub.

## Terraform

HashiCorp Terraform is an infrastructure as code tool that lets you define both cloud and on-prem resources in human-readable configuration files that you can version, reuse, and share. You can then use a consistent workflow to provision and manage all of your infrastructure throughout its lifecycle. Terraform can manage low-level components like compute, storage, and networking resources, as well as high-level components like DNS entries and SaaS features. 
It has been widely adopted by organizations and IT professionals over the years and is recognized as one of the most influential tools in the space. Its cloud-agnostic characteristics, infrastructure as code principles, modularity concepts, and automation capabilities make it a powerful tool that facilitates infrastructure management in any environment.

## Terraform Enterprise

Terraform Enterprise is the self-hosted distribution of Terraform Cloud. It offers enterprises a private instance of the Terraform Cloud application, with no resource limits and with additional enterprise-grade architectural features like audit logging and SAML single sign-on.

## GitHub Actions

GitHub Actions is a modern CI/CD tool integrated natively on GitHub. It provides the possibility to quickly automate build, test, deployment, and other custom workflows on GitHub without needing additional external tools. 
Its focus is to provide an easy and seamless way to automate every software workflow right from GitHub while providing and abstracting all the necessary infrastructure pieces. The tool’s architecture heavily depends on events that trigger further actions combined to generate custom user-defined workflows.
GitHub Actions has evolved into a mature tool in the CI/CD ecosystem over the years and provides many customization options and a robust workflow engine if your team is already using GitHub. A great benefit of using GitHub actions is the open-source community-powered workflows available on GitHub to get you up and running quickly.

## Combine Terraform - Enterprise & GitHub Actions to Manage Infrastructure

To create an automated infrastructure management pipeline with GitOps principles, we can combine GitHub, GitHub Actions, and Terraform Enterprise. The first step would be to store our Terraform code on GitHub. Then, we configure a dedicated GitHub Actions workflow based on our needs that handles infrastructure changes by updating the Terraform configuration files. 

- The workflow will:

1. Develop code against a feature branch and locally run terraform plan as you make changes
2. When you are happy with the plan description create a PR against the main branch in GitHub
3. GitHub Actions will generate a Terraform plan and put it in the PR comments for review
4. Once the code and the plan output is reviewed and accepted it is merged to the main branch
5. GitHub Actions will run terraform apply using the approved plan

### Terraform Code:

The Terraform code creates a dummy application that consists of a GCP Resources. 

### Workflows

What we really want to exhibit is the workflows. We are going to make two of them:

1. When a PR is created against the main branch we want to run terraform plan.
2. When a PR is merged to the main branch we want to run terraform apply.

- Let’s move into the more interesting part: the GitHub Actions workflow definition. To define workflows to run on GitHub Actions runners based on events, create a YAML file inside the ```.github/workflows``` directory of the repository. 

For our example, we define a ```.github/workflows/terraform-action.yaml``` file. The workflow is triggered by the event of a pull request being made against the main branch. 

There is currently only one job in this workflow, ```Terraform``` . It runs on  self-hosted VM with three steps that will execute on it.

- Uses actions/checkout@v2 which by default checks out the code of the branch you are making the PR from.

- Installs Terraform on the VM using hashicorp/setup-terraform.

- It executes a shell script with terraform fmt which will check if the code is formatted correctly or not. If it’s not, the step will fail and will cause the job containing it to also fail. If any step fails it will break the execution of the job.

### Plan

For the next job in the workflow we will execute terraform plan. This is different than the last job. We then want to capture the output of the command and put it into the PR comments for review.
Also a key difference is that the plan action has to connect with some real-world infrastructure to detect the differences between our code, the state, and what we actually have running in GCP.
The matrix strategy is being used so that we create different distinct jobs from one job definition. These will spin up in parallel and be fed a ```matrix.path``` variable to differentiate them.

We’ve also set ```fail-fast: false```. This option will make it so if any one job fails it will not cancel any other in-progress jobs. Potentially terraform plan could fail for one environment and not the other ones. We still want to see the results of terraform plan for all environments even if one of them is failing.

The fourth step is where it starts to get interesting. We are running some shell script to initialize Terraform. Notice how we inject ```${{ matrix.path }}``` in the script so that it will select a different working directory depending on which environment the job is running for.
We set ```-input=false``` because we want Terraform to know this is non-interactive. We don’t want it to potentially ask for human input and cause the GitHub Action runner to hang indefinitely.

Then we get to the plan step and there are a few things to note. We have added an id to this step so that it can be referenced in the next step. We have also explicitly set ```continue-on-error``` to true. If we didn’t set this it would default to false meaning that if the plan step were to fail for any reason the job would not advance to the next step. We do want it to advance to the next step so we can be able to see why the plan may have failed.

The ```-no-color``` flag is set because we only want plain-text output. This will remove the terminal formatting sequences. Although they look nice in a terminal and make the + show as green and the - show as red etc, they will look like gobbledygook inside of a PR comment.

The last step uses an action ```Adarsh-Suvarna/GitHub-PR-Comment```. It has an option to allow repeated comments that are identical. This is useful because you may run multiple plans on the same PR with identical output.

Inside the message of the last action we are referencing ```steps.plan.outputs.stdout``` and ```steps.plan.outputs.stderr```. These are made available to us by the ```hashicorp/setup-terraform``` step we ran earlier. It installs a wrapper script around the Terraform binary which exposes STDOUT and STDERR as outputs. 

The two outputs are logically ORed together so that if ```steps.plan.outputs.stdout``` is not available it will show ```steps.plan.outputs.stderr``` instead. This is what will happen if terraform plan fails for any reason.

### Improvements to plan output

Now if we create a PR we will get a plan comment that looks something like this

### Remove refresh messages

If you’ve ever worked with a large Terraform module you know that the “Refreshing state…” lines can go on and on and on. There can often be hundreds of lines saying this. When reviewing plan output these messages are not useful so lets strip them out.

We do still want refresh to run. We simply don’t want to see its output in our plan message.

The traditional workaround for this has been like so:

``` terraform refresh 2>&1 > /dev/null && terraform plan -refresh=false```

You separate the refresh and plan commands out and redirect the refresh output to ```/dev/null``` to get rid of it.

Unfortunately the refresh command is deprecated now so using this workaround is not future compatible.

A new workaround has surfaced that looks like this:

```terraform plan >/dev/null -out=tfplan```

```terraform show tfplan```

It redirects all of the command’s output to ```/dev/null``` and then opts to make a binary of the plan. The binary can then be read into the terraform show command and it will display essentially the same thing as terraform plan would have minus the “Refreshing state…” messages.

For our use case we want to do it slightly differently:

``` terraform plan -input=false -no-color -out=tfplan \```
```&& terraform show -no-color tfplan ```
We don’t want terraform show running if terraform plan has failed as there will be no tfplan file generated to run against. So we throw in a && to short-circuit things if the first command fails.

We also removed the redirect to ```/dev/null```. This seems counter-intuitive to our goal of suppressing the output from terraform plan but since the ```hashicorp/setup-terraform wrapper``` for STDOUT/STDERR only captures the last Terraform command run in a given action we don’t need to suppress the output.


### Re-Introduce colors

Normally terraform plan output is colorized using terminal formatting sequences. We’ve intentionally removed this using -no-color as it’s not compatible with the plain text we are putting in PR comments. 

```diff
+ Green
- Red
! Orange
@@ Pink @@
# Gray
...
```

and it will show up like this:

We can leverage this to bring some coloring back to our plan messages. It won’t be the same style of coloring but it will at least have the intended effect of placing attention where it needs to be.

Note that the character that controls the color must be at the beginning of the line in order for it to do anything. Otherwise the line will continue to show as plain text. Terraform indents all of its plan output so we will need to move the control characters to the front of the line.

Let’s add another step between the plan and the comment to reformat the output:

      - name: Reformat Plan
        run: |
          echo '${{ steps.plan.outputs.stdout || steps.plan.outputs.stderr }}' \
          | sed -E 's/^([[:space:]]+)([-+])/\2\1/g' > plan.txt      

sed is taking all lines that begin with one or more spaces followed by a + or -. It stores the amount of spaces in \1 and the +/- in \2. Then replace that portion of the line with \2\1 (+/- followed by the number of matched spaces).

The add-pr-comment action will need to reference what’s in plan.txt. It lacks the functionality to do this directly though. It can only reference variables that come in through contexts.

Let’s add yet another step, this time to put the contents of plan.txt into the env context. This is tricky because of the aforementioned limitations of multi-line assignments to outputs and env vars.

      - name: Put Plan in Env Var
        run: |
          PLAN=$(cat plan.txt)
          echo "PLAN<<EOF" >> $GITHUB_ENV
          echo "$PLAN" >> $GITHUB_ENV
          echo "EOF" >> $GITHUB_ENV          

This method essentially constructs a heredoc inside of an environment variable.

Notice how we’ve referenced env.PLAN from the GitHub env context and it’s been place inside of a diff code block.

Plan output will now appear on PRs without the “Refreshing state…” messages and with some nice colors to highlight important changes.

### Branch protection

Branch protection is an optional feature on GitHub repos that you protects branches. We want to protect the main branch in two ways:

- Ensure all plan steps are successful before we can merge
- Ensure the plans we see are up-to-date before we merge

This can easily be achieved by enabling “Require status checks before merging” and setting it to “Require branches to be up to date before merging”.

### Apply

Now let’s make it so when there is a merge to main, terraform apply will be run. This workflow will require much less explaining than the one for terraform plan. We will be straight-up recycling some code from the previous workflow.

At the top we can see this workflow is triggered by a push. When someone hits “Merge”, GitHub will perform a merge and then a push in the background so this is effectively what we want. There is a job to announce that the apply process is running. This is just for UX as it can take several minutes for the actual results of the apply to appear.

The workflow has some control flow logic as there are three outcomes we need to check for:
- The plan fails
- The plan succeeds and the apply fails
- Both the plan and the apply succeed

We use if conditionals to check the steps context so only the appropriate steps are executed.