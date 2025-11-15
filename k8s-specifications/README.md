# Kubernetes Specifications for FastAPI Application

This directory contains all the Kubernetes YAML manifests required to deploy the FastAPI application to a Kubernetes cluster.

## Directory Structure

```
k8s-specifications/
├── 01-namespace.yaml              # Create isolated namespace for the app
├── 02-redis-configmap.yaml        # Redis configuration
├── 03-redis-deployment.yaml       # Redis database deployment
├── 04-redis-service.yaml          # Redis service (internal DNS)
├── 05-fastapi-configmap.yaml      # FastAPI configuration
├── 06-fastapi-deployment.yaml     # FastAPI application deployment
├── 07-fastapi-service.yaml        # FastAPI service (internal DNS)
├── 08-ingress.yaml                # Ingress controller for external access
├── 09-hpa.yaml                    # Horizontal Pod Autoscaler
├── 10-network-policy.yaml         # Network policies for security
└── README.md                       # This file
```

## Prerequisites

Before deploying, ensure you have:

1. **A running Kubernetes cluster** (v1.19+)
   - EKS, AKS, GKE, or any Kubernetes cluster
   - `kubectl` installed and configured

2. **NGINX Ingress Controller** (for external traffic)
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   helm install ingress-nginx ingress-nginx/ingress-nginx \
     --namespace ingress-nginx --create-namespace
   ```

3. **Metrics Server** (for Horizontal Pod Autoscaling)
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

4. **Docker Image** - Push your FastAPI image to a registry
   ```bash
   docker build -t <your-registry>/fast-api-docker-example:latest .
   docker push <your-registry>/fast-api-docker-example:latest
   ```

## Deployment Instructions

### 1. Update Docker Image Reference

Edit `06-fastapi-deployment.yaml` and update the image name:

```yaml
image: <your-registry>/fast-api-docker-example:latest
```

### 2. Deploy All Resources in Order

```bash
# Apply all manifests in order
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-redis-configmap.yaml
kubectl apply -f 03-redis-deployment.yaml
kubectl apply -f 04-redis-service.yaml
kubectl apply -f 05-fastapi-configmap.yaml
kubectl apply -f 06-fastapi-deployment.yaml
kubectl apply -f 07-fastapi-service.yaml
kubectl apply -f 08-ingress.yaml
kubectl apply -f 09-hpa.yaml
kubectl apply -f 10-network-policy.yaml
```

**Or deploy all at once:**

```bash
kubectl apply -f k8s-specifications/
```

### 3. Verify Deployment

```bash
# Check namespace
kubectl get namespace
kubectl get all -n fastapi-app

# Check pods
kubectl get pods -n fastapi-app

# Check services
kubectl get svc -n fastapi-app

# Check ingress
kubectl get ingress -n fastapi-app

# View logs from FastAPI pods
kubectl logs -n fastapi-app -l app=fastapi-app --tail=50 -f
```

## Configuration Details

### Namespace: `fastapi-app`
- Provides logical isolation for all application resources

### Redis Deployment
- **Replicas**: 1 (single instance)
- **Image**: `redis:7-alpine`
- **Port**: 6379
- **Storage**: EmptyDir (non-persistent)
- **Health Checks**: TCP liveness and readiness probes

### FastAPI Deployment
- **Replicas**: 3 (for high availability)
- **Rolling Updates**: Configured for zero-downtime deployments
- **Resource Limits**:
  - CPU: 100m request, 500m limit
  - Memory: 128Mi request, 512Mi limit
- **Health Checks**: HTTP liveness and readiness probes
- **Security**: Non-root user, limited file system access
- **Pod Affinity**: Spread across different nodes when possible

### Services
- **Redis Service**: ClusterIP (internal only)
- **FastAPI Service**: ClusterIP (internal only)

### Ingress
- **Type**: NGINX Ingress Controller
- **Host**: `fastapi.local` (update as needed)
- **Features**:
  - CORS enabled
  - Rate limiting (100 RPS)
  - Body size limit (10MB)

### Horizontal Pod Autoscaler (HPA)
- **Min Replicas**: 2
- **Max Replicas**: 10
- **Metrics**:
  - CPU threshold: 70%
  - Memory threshold: 80%

### Network Policies
- Restricts traffic to FastAPI and Redis pods
- Only allows necessary communication
- Requires network plugin support (Calico, Flannel, etc.)

## Accessing the Application

### Local Development (Port Forward)

```bash
# Port forward to FastAPI service
kubectl port-forward -n fastapi-app svc/fastapi-app 8080:80

# Access at http://localhost:8080
```

### Via Ingress

1. Get the Ingress IP:
   ```bash
   kubectl get ingress -n fastapi-app
   ```

2. Add to `/etc/hosts` (or configure DNS):
   ```
   <ingress-ip> fastapi.local
   ```

3. Access at `http://fastapi.local`

## Testing Endpoints

```bash
# Root endpoint
curl http://fastapi.local/

# Logs endpoint
curl http://fastapi.local/logs

# Hits counter endpoint
curl http://fastapi.local/hits

# Vulnerability endpoint (educational - do not use in production)
# curl http://fastapi.local/vulnerability/test
```

## Monitoring and Debugging

### View Pod Logs
```bash
# All FastAPI pods
kubectl logs -n fastapi-app -l app=fastapi-app -f

# Specific pod
kubectl logs -n fastapi-app <pod-name>

# Previous crashed pod logs
kubectl logs -n fastapi-app <pod-name> --previous
```

### Check Pod Status
```bash
kubectl describe pod -n fastapi-app <pod-name>
```

### Check Events
```bash
kubectl get events -n fastapi-app --sort-by='.lastTimestamp'
```

### Monitor Resources
```bash
kubectl top nodes
kubectl top pods -n fastapi-app
```

## Scaling

### Manual Scaling
```bash
kubectl scale deployment fastapi-app -n fastapi-app --replicas=5
```

### Auto Scaling Status
```bash
kubectl get hpa -n fastapi-app
kubectl describe hpa fastapi-hpa -n fastapi-app
```

## Updating the Application

### Rolling Update
```bash
# Update image
kubectl set image deployment/fastapi-app \
  fastapi=<your-registry>/fast-api-docker-example:v2.0 \
  -n fastapi-app

# Check rollout status
kubectl rollout status deployment/fastapi-app -n fastapi-app
```

### Rollback
```bash
kubectl rollout undo deployment/fastapi-app -n fastapi-app
```

## Cleanup

To delete all resources:

```bash
# Delete entire namespace (deletes all resources within it)
kubectl delete namespace fastapi-app

# Or delete specific resources
kubectl delete -f k8s-specifications/ -n fastapi-app
```

## Advanced Configuration

### Adding TLS/HTTPS

1. Install cert-manager:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
   ```

2. Uncomment the TLS configuration in `08-ingress.yaml`

3. Configure a ClusterIssuer for automatic certificate generation

### Persistent Storage for Redis

Replace the `emptyDir` volume in `03-redis-deployment.yaml` with a PersistentVolumeClaim:

```yaml
volumes:
- name: redis-data
  persistentVolumeClaim:
    claimName: redis-pvc
```

Then create a PersistentVolumeClaim:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-pvc
  namespace: fastapi-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Custom Domain

Update the host in `08-ingress.yaml`:

```yaml
rules:
- host: yourdomain.com
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: fastapi-app
          port:
            number: 80
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n fastapi-app <pod-name>
kubectl logs -n fastapi-app <pod-name>
```

### Redis connection errors
```bash
# Test Redis connectivity
kubectl run -it --rm debug --image=redis:7-alpine --restart=Never -n fastapi-app -- redis-cli -h redis-db ping
```

### Ingress not working
```bash
# Check ingress status
kubectl describe ingress fastapi-ingress -n fastapi-app

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Resource constraints
```bash
# Check node resources
kubectl describe nodes

# Scale down other applications or add more nodes
```

## Security Best Practices

✅ Implemented:
- Non-root user execution
- Resource limits and requests
- Network policies for pod-to-pod communication
- Read-only root filesystem (optional)
- Security contexts at pod level

📋 Recommended:
- Use TLS/HTTPS with cert-manager
- Implement Pod Security Policies or Pod Security Standards
- Use RBAC for fine-grained access control
- Implement container registry authentication
- Regular security scanning of images
- Use secrets for sensitive data instead of environment variables
- Implement audit logging

## Performance Optimization

✅ Implemented:
- Resource requests and limits
- Horizontal Pod Autoscaling
- Pod anti-affinity
- Rolling updates with zero downtime
- Health checks for fast failure detection

📋 Recommended:
- Enable resource quotas at namespace level
- Implement vertical pod autoscaling (VPA)
- Use dedicated node pools for specific workloads
- Implement request/response compression
- Cache headers optimization
- Database query optimization

## Cost Optimization

📋 Recommendations:
- Use spot instances for non-critical workloads
- Implement resource quotas to prevent over-provisioning
- Use cluster autoscaling for dynamic node management
- Compress logs and implement log retention policies
- Consider using smaller images (alpine-based)
- Use namespaces and resource limits for multi-tenant scenarios

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Redis Documentation](https://redis.io/documentation)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
