# Jenkins on Kubernetes

This directory contains a basic example for deploying Jenkins to Kubernetes using Helm. This is an example configuration, so adjust the values to match your environment.

## Add repository

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

## Install Jenkins

```bash
helm install my-jenkins jenkinsci/jenkins --version 5.9.32 -f jenkins-values.yaml -n jenkins --create-namespace
```

## Next steps

- Configure credentials in Jenkins.
- Add the Jenkinsfile to your repository and trigger a build.
- Review the Helm values file to adapt storage, persistence, and plugins to your environment.
