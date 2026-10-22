# Northstar checkout delivery pipeline

Lab repository for M03 D07, *Ship The Northstar Checkout From Commit To
Production*. Create your own copy with **Use this template**, keep it
**public**, and keep the name `northstar-checkout-pipeline`.

| Path | Content |
| --- | --- |
| `app/` | The Northstar checkout, its unit tests in `app/tests/` and the tools of the tests in `requirements-dev.txt` |
| `.github/workflows/pipeline.yml` | The pipeline. It starts with the tests only, and the lab adds the next stages |
| `.github/workflows/deploy.yml` | Deploys one image tag to staging or production. The pipeline calls it, and you can run it by hand to roll back |
| `lab-steps/` | The next versions of `pipeline.yml`, which the lab copies in place one at a time |
| `k8s/base/` | The Deployment of the checkout, the same in every environment |
| `k8s/staging/`, `k8s/prod/` | What changes per environment: namespace, number of copies, configuration |
| `platform/` | What the platform team creates once: the cluster, the namespaces, the load balancers, the IAM policy and trust policy of the pipeline |
| `scripts/smoke-test.sh` | The test that runs after each deployment |
| `challenge/` | Starter files of the canary challenge |

Everything runs from AWS CloudShell in Europe (Paris), `eu-west-3`. The
cluster bills by the hour until you delete it:

```bash
kubectl delete -f platform/services.yaml     # deletes the two load balancers first
eksctl delete cluster -f platform/cluster.yaml --disable-nodegroup-eviction --wait
aws ecr delete-repository --repository-name northstar/checkout --force
```
