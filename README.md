# CDRC data repository platform

This project is host by CDRC.
The project is based on [CKAN](https://github.com/ckan/ckan) and using [Docker](https://www.docker.com) for shipment.

## Setup

To run the platform, one need to install [docker](https://docs.docker.com/installation/#installation).
Then simply check out this repo and build the docker image by

```bash
docker build cdrc_repo/cdrc_repo .
```

## Customize credential

When starting a container from the image, one should specify the following environment variables for change the default credential.
Otherwise the platform may be under risk.

TODO
