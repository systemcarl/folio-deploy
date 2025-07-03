# folio-deploy
These automation tools contain the code and configuration files for building and
deploying the [`folio`](https://github.com/systemcarl/folio) application. The
application is built and bundled using the *SvelteKit* *Node.js* adapter and the
output is containerized into a *Docker* image.

## Prerequisites
To execute the provided scripts, the following dependencies are required:
- [*Docker*](https://www.docker.com/get-started)
- [*Node.js*](https://nodejs.org/en/download/) (recommended v22.16 or later)
- [*Terraform*](https://developer.hashicorp.com/terraform/install) (recommended
    v1.12.2 or later)

### Environment Variables
All variables can be set in the execution environment, included in a `.env`
file in the root of the repository, or passed as arguments to the scripts —
evaluated in that order.

The following environment variables are used during the execution of the
scripts:
- `ENVIRONMENT`: The environment being deployed. Expected to be either
    `production` or `staging`. Environment state is stored separately in the
    same *Google Cloud Storage* bucket.
- `GOOGLE_CREDENTIALS`: The path to the *Google Cloud Service* credentials
    JSON file. Used by default during deployment operations.
- `FOLIO_APP_DOMAIN`: The domain name of the deployed application.
- `FOLIO_CF_DNS_ZONE`: The *Cloudflare* DNS of the domain of the application
    domain. Used to update the DNS records.
- `FOLIO_SSH_PORT`: The configured SSH port the deployed application server.
- `FOLIO_ACME_EMAIL`: The email address used to register the *Let's Encrypt*
    SSL certificate for the application domain.
- `FOLIO_SSH_KEY_ID`: The *DigitalOcean* identifier of the SSH key used to
    initialize the application server.
- `FOLIO_PUBLIC_KEY_FILE`: The path to the public key file used by the
    default user of the deployed application server. Respective private key
    can be used to access the application server after deployment as user `app`.
- `FOLIO_GCS_CREDENTIALS`: The path to the *Google Cloud Service* credentials
    JSON file. Overrides the global `GOOGLE_CREDENTIALS` variable.
- `FOLIO_CF_TOKEN`: The *Cloudflare* API token used to update the DNS records
    of the application domain. See [*Deployment*](#deployment) for required
    permission scopes.
- `FOLIO_DO_TOKEN`: The *DigitalOcean* API token used to create and manage
    the application server. See [*Deployment*](#deployment) for required
    permission scopes.
- `FOLIO_GH_TOKEN`: The *GitHub* API token used to update the commit status
    of the application and CI/CD pipeline. See [*Status*](#code-status) for
    required permission scopes.

## Validation
Before building the application, you can validate the application code using
the `validate` script. This script will run all tests defined in the `folio`
application.
```bash
validate
```

## Build & Containerization
To build and containerize a deployable application, run the provided
containerization script. If successful, the script resulting image will be
tagged as `folio:latest` and pushed to the local *Docker* registry.
```bash
containerize
```

To push to the *GitHub Packages* registry, option `--push` can be used. To see
the full list of options, run the script with the `--help` option.
```bash
containerize --push
```

## Deployment
The `folio` application can be deployed to a remote server or a local *Docker*
instance for development and testing using the `deploy` script. To see the full
list of options, run the script with the `--help` option.
```bash
deploy --help
```

### Remote Deployment
By default, the script will attempt to deploy the application to a remote
server by applying a *Terraform* plan. Appropriate configuration must be
provided; see the script usage for details for more information.
```bash
deploy
```

The configured *Cloudflare* API token must have the scopes, for all applicable
zones:
- `DNS:Edit`.

The configured *DigitalOcean* API token must have the scopes:
- `droplet:create`,
- `droplet:read`,
- `droplet:update`,
- `droplet:delete`.
- `reserved_ip:read`,
- `reserved_ip:create`,
- `reserved_ip:update`,
- `reserved_ip:delete`.
- `ssh_key:read`,
- `tag:read`,
- `tag:create`,
- `tag:delete`

To automatically apply the *Terraform* plan without interaction, you can
add the `--approve` option.
```bash
deploy --approve
```

Remote deployment requires that the requested `folio` *Docker* image version is
available on *GitHub Packages*.

#### Staging
To avoid exposing potentially unstable code or hitting rate limits during
testing, the `--staging` option can be used to deploy the application to a
staging environment.
```bash
deploy --staging
```

When staging, a staging SSL certificate will be issued by *Let's Encrypt*,
instead of a production certificate.

### Local Deployment
If the `--local` option is used, the script will attempt to run the application
on a local container, exposing port 3000. The latest image will be pull from the
local *Docker* registry, or if unavailable, the *GitHub Packages* registry.
port `3000`.
```bash
deploy --local
```

## Cleanup
To tear down the application, either to cleanup local development or destroy the
remote resources, the `destroy` script can be executed. A usage description
can be obtained by running the script with the `--help` option.
```bash
destroy --help
```

### Remote Cleanup
To destroy the remote resources, the script requires the same environment
configuration as the `deploy` script. The parameters are required to ensure the
correct resources are identified and destroyed by *Terraform*.
```bash
destroy
```

To automatically apply approve the destruction of all resources, add the
`--approve` option.
```bash
destroy --approve
```

### Local Cleanup
To clean up the local resources, the script will attempt to stop and remove the
`folio` container, and remove the local *Docker* image.
```bash
destroy --local
```

## Testing
This deployment project includes a test suite that can be run to ensure all
non-application deployment code is functioning as expected.
```bash
test
```
Script unit tests are run using a *BATS* *Docker* container that is
automatically pulled and executed. Terraform tests are executed using the
*Terraform* CLI.

To target specific test files, you can pass an individual test file or directory
as an argument to the `test` script. Tests can also be filtered by name using
the `--filter` option. Only *BATS* test files can be narrowed by file or test
name.
```bash
test <file_or_directory> --filter <test_name>
```

To isolate a specific test suite — either *cli* or *infrastructure* tests — you
can use the `--cli` or `--infra` options, respectively. Infrastructure tests
include both the *Terraform* and `cloud-init` script tests. *Terraform* tests
can be run in isolation using the `--terraform` option.
```bash
test --cli
test --infra
test --terraform
```

### Code Status
The commit status of both the `folio` application and the `folio-deploy` CI/CD
pipeline can be retrieved from *GitHub*. By default, the `status` script
retrieves the status of the `folio` application's current head of the main
branch. Alternatively, a branch, tag, or commit SHA as an argument to the
script. To target the `folio-deploy` CI/CD pipeline, the `--self` option can be
used.
```bash
status [<application_commit>]
status --self [<pipeline_commit>]
```

The commit status can be set manually using the `set` subcommand. The subcommand
requires a status argument, which can be one of `success`, `failure`, or
`pending`. Optionally, the target commit can be specified before the status
argument.
```bash
status set [<application_commit>] <status>
status set --self [<pipeline_commit>] <status>
```

The configured *GitHub* API token must have the scopes:
- `commit_status:read`,
- `commit_status:write`,
- `contents:read`
