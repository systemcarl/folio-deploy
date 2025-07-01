# folio-deploy
These automation tools contain the code and configuration files for building and
deploying the [`folio`](https://github.com/systemcarl/folio) application. The
application is built and bundled using the *SvelteKit* *Node.js* adapter and the
output is containerized into a *Docker* image.

## Prerequisites
To execute the provided scripts, the following dependencies are required:
- [*Docker*](https://www.docker.com/get-started)

## Testing
This deployment project includes a test suite that can be run to ensure all
non-application deployment code is functioning as expected. Script unit tests
are run using a *BATS* *Docker* container that is automatically pulled and
executed.
```bash
test
```
