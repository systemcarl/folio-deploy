# folio-deploy
These automation tools contain the code and configuration files for building and
deploying the [`folio`](https://github.com/systemcarl/folio) application. The
application is built and bundled using the *SvelteKit* *Node.js* adapter and the
output is containerized into a *Docker* image.

## Prerequisites
To execute the provided scripts, the following dependencies are required:
- [*Docker*](https://www.docker.com/get-started)
- [*Node.js*](https://nodejs.org/en/download/) (recommended v22.16 or later)

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
The `folio` application can be deployed to a locally running *Docker* engine
using the `deploy` script. This script will pull the latest image from the local
*Docker* registry or the *GitHub Packages* registry and run it in a container on
port `3000`.
```bash
deploy
```

To cleanup the running container, run the `destroy` script, which will stop and
remove the container running the `folio` application.
```bash
destroy
```

## Testing
This deployment project includes a test suite that can be run to ensure all
non-application deployment code is functioning as expected. Script unit tests
are run using a *BATS* *Docker* container that is automatically pulled and
executed.
```bash
test
```

To target specific test files, you can pass an individual test file or directory
as an argument to the `test` script. Tests can also be filtered by name using
the `--filter` option.
```bash
test <file_or_directory> --filter <test_name>
```
