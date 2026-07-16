# Vaultwarden Production Deployment Guide (Helm, Kubernetes)

This guide walks through deploying Vaultwarden on a Kubernetes cluster using
the [guerzon/vaultwarden](https://github.com/guerzon/vaultwarden-helm) Helm
chart, with all secrets kept out of `values.yaml` (and therefore out of git).

## Prerequisites

- A running Kubernetes cluster with `kubectl` configured
- Helm 3 installed
- An ingress controller (this guide assumes `ingress-nginx`)
- cert-manager installed, with a working `ClusterIssuer`
- A reachable PostgreSQL instance (this chart does **not** deploy a database)
- A default `StorageClass`, or the name of the one you want to use

Check what you already have before starting:

```bash
kubectl get clusterissuer
kubectl get storageclass
kubectl get ingressclass
```

---

## 1. Create a namespace

```bash
kubectl create namespace vaultwarden
```

---

## 2. Provision the database

The chart expects an existing PostgreSQL database and user — create them on
your Postgres instance:
```bash
openssl rand -base64 32
```
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql \
  --namespace vaultwarden \
  --set auth.username=vaultwarden \
  --set auth.password="$(openssl rand -base64 32)" \
  --set auth.database=vaultwarden \
  --set primary.persistence.size=5Gi
```
```bash
export POSTGRES_ADMIN_PASSWORD=$(kubectl get secret --namespace vaultwarden postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
```
```bash
export POSTGRES_PASSWORD=$(kubectl get secret --namespace vaultwarden postgres-postgresql -o jsonpath="{.data.password}" | base64 -d)
```
```bash
kubectl port-forward --namespace vaultwarden svc/postgres-postgresql 5432:5432 &
```
```bash
PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" psql --host 127.0.0.1 -U postgres -d vaultwarden -p 5432
```

```sql
CREATE DATABASE vaultwarden;
CREATE USER vaultwarden WITH ENCRYPTED PASSWORD '<generate-a-strong-password>';
GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO vaultwarden;
```

Generate a strong password rather than typing one:



---

## 3. Create Kubernetes Secrets (nothing goes in values.yaml)

Every credential below is created as a Secret directly in the cluster. None
of this ever touches a file that gets committed to git.

### 3.1 Database connection string

```bash
kubectl create secret generic vaultwarden-db-secret \
  --namespace vaultwarden \
  --from-literal=database-url="postgresql://vaultwarden:$POSTGRES_PASSWORD@postgres-postgresql:5432/vaultwarden"
```

### 3.2 Admin panel token

```bash
ADMIN_TOKEN=$(openssl rand -base64 48)

kubectl create secret generic vaultwarden-admin-secret \
  --namespace vaultwarden \
  --from-literal=admin-token="$ADMIN_TOKEN"

echo "Save this somewhere safe, it will not be shown again: $ADMIN_TOKEN"
```

### 3.3 SMTP credentials (required for invites, password resets, 2FA emails)

```bash
kubectl create secret generic vaultwarden-smtp-secret \
  --namespace vaultwarden \
  --from-literal=smtp-user="<smtp-username>" \
  --from-literal=smtp-password="<smtp-password>"
```

### 3.4 Push notifications (optional — only if you use official mobile apps)

Get these from https://bitwarden.com/host/ if you want push notifications to
work on mobile. Skip this section and set `push.enabled: false` if you don't
need it.

```bash
kubectl create secret generic vaultwarden-push-secret \
  --namespace vaultwarden \
  --from-literal=push-id="<installation-id>" \
  --from-literal=push-key="<installation-key>"
```

### 3.5 SSO / OIDC (optional)

```bash
kubectl create secret generic vaultwarden-sso-secret \
  --namespace vaultwarden \
  --from-literal=sso-client-id="<client-id>" \
  --from-literal=sso-client-secret="<client-secret>"
```

> **Prefer Vault over kubectl?** If you already run HashiCorp Vault with the
> Kubernetes auth method configured, use the Vault Agent injector instead of
> `kubectl create secret` — annotate the Vaultwarden pod template to pull
> these values from Vault at pod startup rather than storing them as native
> Kubernetes Secrets. Out of scope for this guide, but worth doing if Vault
> is already part of your stack.

---

## 4. Fill in `values.yaml`

Take the template from the previous step and replace every secret-shaped
field with a reference to the Secret you just created, instead of an inline
value. Non-secret fields (domain, ingress class, storage size) still need to
be filled in directly.

```yaml
database:
  type: postgresql
  wal: true
  url: ""
  existingSecret: "vaultwarden-db-secret"
  existingSecretKey: "database-url"
  maxConnections: 10
  minConnections: 2

vaultwarden:
  domain: "https://vault.yourdomain.com"      # your real domain
  allowSignups: false
  signupDomains: []
  verifySignup: true
  requireEmail: true                          # tightened, see note below

  admin:
    enabled: true
    disableAdminToken: false
    existingSecret: "vaultwarden-admin-secret"

  smtp:
    enabled: true
    host: "smtp.yourprovider.com"
    from: "vaultwarden@yourdomain.com"
    fromName: "Vaultwarden"
    security: starttls
    port: "587"
    existingSecret: "vaultwarden-smtp-secret"

  push:
    enabled: true                              # set false to skip section 3.4
    existingSecret: "vaultwarden-push-secret"

  sso:
    enabled: false                             # true only if you set up 3.5
    existingSecret: "vaultwarden-sso-secret"

ingress:
  enabled: true
  className: "nginx"
  host: "vault.yourdomain.com"
  annotations:
    cert-manager.io/cluster-issuer: "<your-clusterissuer-name>"
    nginx.ingress.kubernetes.io/proxy-body-size: "128m"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  tls:
    - secretName: vaultwarden-tls
      hosts:
        - "vault.yourdomain.com"

persistence:
  enabled: true
  size: "10Gi"
  storageClass: ""    # empty = cluster default; set explicitly if you don't have one

image:
  tag: "1.33.2-alpine"   # pin a version, check for newer ones before deploying
```

> **Why `requireEmail: true`:** with `allowSignups: false` you're already
> controlling who gets an account manually — tightening `requireEmail`
> closes the gap where `verifySignup: true` sends a verification email but
> login doesn't actually require it to be confirmed.

---

## 5. Install

```bash
helm repo add vaultwarden https://guerzon.github.io/vaultwarden
helm repo update

helm install vaultwarden vaultwarden/vaultwarden \
  --namespace vaultwarden \
  -f values.yaml
```

---

## 6. Verify

```bash
kubectl get pods -n vaultwarden -w
kubectl get pvc -n vaultwarden
kubectl get ingress -n vaultwarden
kubectl describe certificate -n vaultwarden   # cert-manager should show Ready: True
```

If the pod is stuck `Pending`, check the PVC first — that's almost always a
missing default StorageClass:

```bash
kubectl get storageclass
kubectl describe pvc -n vaultwarden
```

If the pod is `CrashLoopBackOff`, check logs for a database connection
failure first — the most common first-deploy issue is the DB not being
reachable from inside the cluster network, or the user/password/database
name not matching what you created in step 2:

```bash
kubectl logs -n vaultwarden deploy/vaultwarden
```

---

## 7. After it's working

- **Lock down the admin panel.** Once your organization/accounts are set up,
  either set `vaultwarden.admin.enabled: false` and `helm upgrade`, or
  restrict access to it at the ingress level (IP allowlist annotation, or a
  separate internal-only Ingress) rather than relying on the token alone.
- **Back up the database and the persistent volume**, not just one or the
  other — Vaultwarden stores attachments on disk (the PVC) and everything
  else in Postgres.
- **Re-run `helm upgrade` instead of editing live resources** whenever you
  change `values.yaml`, so the cluster state and your git history stay in
  sync:

```bash
helm upgrade vaultwarden vaultwarden/vaultwarden \
  --namespace vaultwarden \
  -f values.yaml
```

## Problems you may have
### Admin token

1) If not working try watch is pod env ADMIN_TOKEN present.
2) edit statful set to use env : admin-config=vaultwarden-admin-token and key must be 'admin-token'='TOKEN' (not 'ADMIN_TOKEN'='TOKEN')
---

