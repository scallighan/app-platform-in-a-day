---
parent: Azure Container Instances
title: Considerations
nav_order: 3
---
# Azure Container Instances | Considerations
*— I have a container image; I want to run it fast in the Cloud. Uptime is not very important to me.​*
​
What for: Serverless isolated containers: simple applications, task automation and build jobs​

Who: Teams looking for a serverless compute platform to run their standalone, containerized workload (CI/CD build agent, dev/test workload, batch job). Those who need orchestration can plug into other services such as AKS Virtual Node or Logic App's ACI Connector​

Why: Teams will often encounter ACI by the experiences it powers (e.g., AKS virtual nodes, Container apps), but for some specialized workloads, teams may target ACI directly. Some use ACI for unopinionated containers to power experiences like Codespaces or running batch jobs like Data processing pipelines requiring a container without additional orchestration. 

Customer journey: App Services is the optimal starting point for web-based applications.