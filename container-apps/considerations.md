---
parent: Azure Container Apps
title: Considerations
nav_order: 3
---
# Azure Container Apps | Considerations
*— I have containerized microservices and/or event driven workloads. I want to run them and not deal with any infrastructure or container orchestrator. AKS is far more than what I need.*

Who:  Teams building fully-managed cloud native microservices, without needing to interface with the Kubernetes APIs directly

Why:  Many teams are looking to build modern microservices, but also may not want or need to deal with underlying Kubernetes concept or operations overhead. This provides a Simple API to deploy containers and modern microservices.

Customer journey:  Teams that start with Container Apps will have a path to move to Kubernetes/AKS when required (want access to lower-level concepts like daemons or stateful-sets, or flexibility to modify underlying cluster assets (e.g., install custom 3rd party libraries)
