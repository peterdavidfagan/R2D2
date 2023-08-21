# Overview

In order to simplify the setup and deployment of R2D2 across different machines we supply Dockerfiles for both the control server (nuc) and the client machine (laptop). The directory structure is broken down as follows: 

    ├── nuc # directory for nuc docker setup files
    ├──── Dockerfile.nuc # nuc image definition
    ├──── docker-compose-nuc.yaml # nuc container deployment settings
    ├── laptop # directory for laptop docker setup files
    ├──── Dockerfile.laptop # laptop image definition
    ├──── docker-compose-laptop.yaml # laptop container deployment settings

We recognise that some users may not already be familiar with Docker and the syntax of Dockerfiles and docker compose configuration files. We point the user towards the following resources on these topics:

* [Docker Overview](https://docs.docker.com/get-started/overview/)
* [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
* [Docker Compose Overview](https://docs.docker.com/compose/)


# NUC Setup

# Laptop Setup  

