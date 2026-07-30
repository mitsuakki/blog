---
layout: project
title: "bds-sdk-generator"
repo: "sarumc/bds-sdk-generator"
repo_url: "https://github.com/sarumc/bds-sdk-generator"
description: "A utility for reconstructing symbols from the PDB into compilable C headers"
language: "C++"
stars: 2
updated: "2026-03-14T10:17:52Z"
topics: [bedrock-dedicated-server, cmake, demangle-symbols, docker, llvm, microsoft, minecraft]
readme_sha: "6623b026ea0051651b55b0f48b34134b6e003dd5"
sync_status: "new"
archived: true
lang: en
---

> [!WARNING]
> There is also a better utility for reconstructing structures and unions from the PDB into compilable C headers. <br>
> I recommend you to "not use" bds-sdk-generator, unless you want to reformat by hand every-symbols you dumped from the PDB.
> Go check this [pdbexe](https://github.com/SaruMC/pdbexe) or wait until the next update of our tool.

# About
This repository concerns the generation of Minecraft Bedrock Dedicated Server (BDS) header files through the PDB file provided with the release of each BDS version.

## Compilation

### Local Build
To build this locally, you need to have LLVM and Clang installed on your machine. Refer to the LLVM documentation for more information.

Here's how you can download it on Ubuntu/Debian:

```shell
sudo apt-get update
sudo apt-get install llvm clang
```

Then, to compile the project:

```shell
mkdir -p build && cd build
cmake ..
make
```

### Docker Build
You can also use Docker to build this project, which ensures a consistent build environment. The provided Dockerfile installs all necessary dependencies and sets up the build environment.

To build the Docker image:

```shell
podman build --build-arg BDS_VERSION=<desired_version> -t bds-sdk-gen .
```

Replace `<desired_version>` with the desired BDS version you wish to use. For example, `1.16.201.02`.

To run the Docker container:

```shell
podman run --rm -v $(pwd)/bin:/usr/src/app/bin bds-sdk-gen
```

### Important Note

> [!IMPORTANT]
> Microsoft has decided to remove PDB files from the BDS sources as of the latest versions. As a result, we cannot generate headers for BDS versions released after the latest version available at https://mcbds.reh.tw/. Please ensure that you are using a compatible version available from this resource.
