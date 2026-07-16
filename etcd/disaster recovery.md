# 📘 Инструкция по восстановлению etcd (Runbook)

## 📦 Этап 1: Резервное копирование (Backup)
Выполните эти команды, чтобы сохранить текущее состояние базы.

```bash
# Создание снимка данных
# ВАЖНО: Замените IP и порты на свои (обычно 2379 для клиента)
ETCDCTL_API=3 etcdctl snapshot save /mnt/data/etcdSnapshots/data.db \
  --endpoints=https://<IP_АДРЕС_ETCD>:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Копирование сертификатов
cp -r /etc/kubernetes/pki /mnt/data/etcdSnapshots/
```
> 🔍 **Где взять IP и порты?**
> В файле `/etc/kubernetes/manifests/etcd.yaml` в секции `containers` посмотрите на параметр `--advertise-client-urls`.

---

## 🚀 Этап 2: Восстановление (Restore)
Восстановление данных из снимка в новую директорию.

```bash
# Восстановление из снимка
# ВАЖНО: Все параметры ниже должны строго совпадать с вашим etcd.yaml
ETCDCTL_API=3 etcdctl snapshot restore /mnt/data/etcdSnapshots/data.db \
  --name=<ИМЯ_УЗЛА> \
  --initial-cluster=<СТРОКА_INITIAL_CLUSTER> \
  --initial-advertise-peer-urls=https://<IP_АДРЕС>:<ПОРТ_PEER> \
  --data-dir=/var/lib/etcd
```
> 🔍 **Где взять эти значения?**
> Откройте файл `/etc/kubernetes/manifests/etcd.yaml` и скопируйте значения из этих строк:
> 1. `--name` — (например, `master`)
> 2. `--initial-cluster` — (строка вида `master=https://10.x.x.x:2380...`)
> 3. `--initial-advertise-peer-urls` — (ссылка на порт 2380)
> 4. `--data-dir` — (обычно `/var/lib/etcd`)

---

## 🔍 Этап 3: Проверка системы
После восстановления нужно проверить, поднялся ли контейнер и заработал ли Kubernetes.

```bash
# 1. Находим ID контейнера etcd
crictl ps -a | grep etcd

# 2. Смотрим логи (если контейнер упал или не стартует)
# Замените <ID> на то, что получили из предыдущей команды
crictl logs $(crictl ps -a | grep etcd | awk '{print $1}')

# 3. Проверяем наличие файлов данных
ls -la /var/lib/etcd/
ls -la /var/lib/etcd/member

# 4. Проверяем и запускаем основной сервис Kubelet
systemctl status kubelet
systemctl start kubelet
systemctl status kubelet
```

---

## 📊 Этап 4: Мониторинг
Используйте эти команды для контроля процесса в реальном времени.

| Задача | Команда |
| :--- | :--- |
| **Следить за контейнерами** | `watch crictl ps` |
| **Следить за узлами** | `watch kubectl get nodes` |
| **Следить за подами в системе** | `watch kubectl get pods -n kube-system` |
| **Общий статус всех ресурсов** | `kubectl get all -A` |

---
**💡 Совет для админа:** Если команда `snapshot restore` ругается на права доступа к папке `/var/lib/etcd`, выполните: `chown -R root:root /var/lib/etcd` перед повторной попыткой.

# TL;DR
## Automated don't need.
```
ETCDTL_API=3 etcdctl snapshot save /mnt/data/etcdSnapshots/data.db --endpoints=https://IP_PLACEHOLDER:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key
cp -r /etc/kubernetes/pki /mnt/data/etcdSnapshots/
cp /etc/kubernetes/manifests/etcd.yaml /mnt/data/etcdSnapshots/
cat /etc/kubernetes/manifests/etcd.yaml
```

## Recovery
```
cat /etc/kubernetes/manifests/etcd.yaml
```
```
ETCDCTL_API=3 etcdctl snapshot restore /mnt/data/etcdSnapshots/data.db   --name=master   --initial-cluster=master=https://IP_PLACEHOLDER:2380   --initial-advertise-peer-urls=https://IP_PLACEHOLDER:2380   --data-dir=/var/lib/etcd
```
```
crictl ps -a | grep etcd
# Смотри логи если есть (даже если crashed)
crictl logs $(crictl ps -a | grep etcd | awk '{print $1}')
ls -la /var/lib/etcd/
ls -la /var/lib/etcd/member
```
`systemctl status kubelet`
```systemctl start kubelet```
`systemctl status kubelet`
```
watch crictl ps
kubectl get all -A
watch kubectl get pods -n kube-system
watch kubectl get nodes
```