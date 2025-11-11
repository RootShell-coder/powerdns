# Kubernetes Manifests for PowerDNS

This directory contains Kubernetes manifests to deploy PowerDNS with MariaDB.

## Components

- `configmap.yaml`: Configuration for PowerDNS
- `secret.yaml`: Secrets for MariaDB
- `mariadb-pvc.yaml`: Persistent volume claim for MariaDB data
- `poweradmin-pv.yaml`: Persistent volume for PowerAdmin data (hostPath for local testing, 200Mi)
- `poweradmin-pvc.yaml`: Persistent volume claim for PowerAdmin data (200Mi)
- `mariadb-deployment.yaml`: Deployment for MariaDB
- `mariadb-service.yaml`: Service for MariaDB
- `powerdns-deployment.yaml`: Deployment for PowerDNS
- `powerdns-service.yaml`: ClusterIP service for PowerDNS (no exposed ports, use port-forwarding)

## Deployment

1. Apply all manifests:

   ```bash
   kubectl apply -f k8s/
   ```

2. Initialize the database:
   - Get the MariaDB pod: `kubectl get pods`
   - Copy schema: `kubectl cp schema.mysql.sql <mariadb-pod>:/tmp/`
   - Import: `kubectl exec <mariadb-pod> -- mariadb -u pdns_user -p pdns_db < /tmp/schema.mysql.sql`

3. Access PowerAdmin using port-forwarding: `kubectl port-forward svc/powerdns-service 8080:80` then visit localhost:8080/poweradmin

4. DNS is available directly on node IP:53

## Notes

- Adjust storage sizes as needed.
- For production, use proper secrets management.
- DNS uses hostPort, so the pod will run on a single node and port 53 is exposed directly on the host.
- HTTP access via port-forwarding or reverse proxy (e.g., Ingress).
- DNS service may need additional configuration for external access.
