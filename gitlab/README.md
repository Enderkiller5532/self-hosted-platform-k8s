# GitLab on Kubernetes

This directory contains a manual deployment example for installing GitLab with PostgreSQL, Redis, and object storage integration in a Kubernetes cluster.

## Prerequisites

- A running Kubernetes cluster
- Helm installed
- kubectl configured
- Access to an object storage backend such as MinIO

## Add Helm repository

```bash
helm repo add gitlab http://charts.gitlab.io/
```

## Create secrets

Create the required secrets for Redis, PostgreSQL, object storage, and registry storage:

```bash
# Example only: replace with your own secure values
kubectl create secret generic gitlab-redis-password \
  --from-literal=password='YOUR_REDIS_PASSWORD' \
  -n gitlab
```

```bash
# Example only: replace with your own secure values
kubectl create secret generic gitlab-psql-password \
  --from-literal=password='YOUR_POSTGRES_PASSWORD' \
  -n gitlab
```

```bash
# Example only: replace with your own storage settings
kubectl create secret generic gitlab-object-storage \
  --from-literal=connection='provider: AWS
region: us-east-1
aws_access_key_id: YOUR_ACCESS_KEY
aws_secret_access_key: YOUR_SECRET_KEY
endpoint: "http://YOUR_OBJECT_STORAGE_HOST:9000"
path_style: true' \
  -n gitlab
```

```bash
# Example only: replace with your own storage settings
kubectl create secret generic gitlab-registry-storage \
  --from-literal=config='s3:
  accesskey: YOUR_ACCESS_KEY
  secretkey: YOUR_SECRET_KEY
  region: us-east-1
  regionendpoint: http://YOUR_OBJECT_STORAGE_HOST:9000
  bucket: registry
  secure: false
  v4auth: true' \
  -n gitlab
```
### Instatall Postgresql
```
helm install postgresql bitnami/postgresql   -n gitlab   --set auth.username=gitlab   --set auth.password='gitlabP@ssw0rd'   --set auth.database=gitlabhq_production   --set primary.persistence.size=10Gi
```
### Export password
```
export POSTGRES_ADMIN_PASSWORD=$(kubectl get secret --namespace gitlab postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
export POSTGRES_PASSWORD=$(kubectl get secret --namespace gitlab postgresql -o jsonpath="{.data.password}" | base64 -d)
```
### Sync PostgreSQL password to GitLab secret
Аналогично Redis — bitnami-чарт PostgreSQL хранит реальный пароль в собственном секрете `postgresql`, который может не совпадать с тем, что вручную положен в `gitlab-psql-password`. Синхронизируй перед стартом GitLab chart:

```bash
REAL_PSQL_PASS=$(kubectl get secret postgresql -n gitlab -o jsonpath='{.data.password}' | base64 -d)
kubectl delete secret gitlab-psql-password -n gitlab
kubectl create secret generic gitlab-psql-password \
  --from-literal=password="$REAL_PSQL_PASS" \
  -n gitlab
```

⚠️ Правило на будущее: для **любого** bitnami-чарта (postgresql, redis) всегда сверяй фактический пароль из авто-сгенерированного секрета релиза, а не полагайся на значение, переданное через `--set auth.password=` при установке.
### Connect to db and add all we need
```
    kubectl port-forward --namespace gitlab svc/postgresql 5432:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host IP_PLACEHOLDER -U gitlab -d gitlabhq_production -p 5432
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
```

## Install Redis

```bash
helm install redis bitnami/redis \
  -n gitlab \
  --set auth.password='gitlabP@ssw0rd' \
  --set architecture=standalone \
  --set master.persistence.size=5Gi
```
### Export passwords
```
export REDIS_PASSWORD=$(kubectl get secret --namespace gitlab redis -o jsonpath="{.data.redis-password}" | base64 -d)
```
### Sync Redis password to GitLab secret
Bitnami Redis chart generates its own password internally (в helm install `--set auth.password=` иногда не применяется к автосгенерированному секрету релиза). Нужно взять реальный пароль из secret `redis` и продублировать в `gitlab-redis-password`:

```bash
REAL_REDIS_PASS=$(kubectl get secret redis -n gitlab -o jsonpath='{.data.redis-password}' | base64 -d)
kubectl delete secret gitlab-redis-password -n gitlab
kubectl create secret generic gitlab-redis-password \
  --from-literal=password="$REAL_REDIS_PASS" \
  -n gitlab
```

### Connect gitlab to minio
```
# Example only: replace these values with your own MinIO/S3 settings
cat > s3cfg << 'EOF'
[default]
access_key = YOUR_ACCESS_KEY
secret_key = YOUR_SECRET_KEY
host_base = http://YOUR_OBJECT_STORAGE_HOST:9000
host_bucket = http://YOUR_OBJECT_STORAGE_HOST:9000
use_https = False
signature_v2 = False
EOF
```

```bash
kubectl create secret generic gitlab-backup-s3cfg \
  --from-file=config=s3cfg \
  -n gitlab
```
### On minio server use mc to create bucket
```
# Example only: replace these values with your own MinIO/S3 settings
mc alias set myminio http://YOUR_OBJECT_STORAGE_HOST:9000 YOUR_ACCESS_KEY YOUR_SECRET_KEY
mc mb myminio/registry
mc mb myminio/git-lfs
mc mb myminio/gitlab-artifacts
mc mb myminio/gitlab-uploads
mc mb myminio/gitlab-packages
mc mb myminio/gitlab-backups
```

## Install GitLab

```bash
helm install gitlab gitlab/gitlab --version 10.1.2 -n gitlab -f values-gitlab.yaml
```
### TL;DR
It activetes Gitlab,Gitlab-runner,Git-registy.

# Trobleshoot

REAL_REDIS_PASS=$(kubectl get secret redis -n gitlab -o jsonpath='{.data.redis-password}' | base64 -d)
kubectl delete secret gitlab-redis-password -n gitlab
kubectl create secret generic gitlab-redis-password \
  --from-literal=password="$REAL_REDIS_PASS" \
  -n gitlab

### Troubleshooting: ImagePullBackOff / corrupted containerd blob
Если под падает с ошибкой вида `blob not found: not found` — это повреждённый локальный кэш containerd, а не сетевая проблема. Почисти образ на конкретной ноде (смотри `Node:` в `kubectl describe pod`):

```bash
crictl rmi <image>
kubectl delete pod <pod-name> -n gitlab
```

## Notes

- Replace the placeholder credentials and endpoints with values that match your environment.
- Review the values file before deploying GitLab in a production environment.
