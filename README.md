Prototype: Client Management Workflow
 Version Control

| Date       | Version | Author | Description                                                                       |
| ---------- | ------- | ------ | --------------------------------------------------------------------------------- |
| 26.09.2025 | 0.1     | Bill   | Initial draft: basic workflow with Minikube, client create/update/suspend/resume. |


1. Start a Cluster
minikube start
minikube tunnel

2. Create a Client
.\new-client.bat bill (for window)
./new-client.sh bill (for Mac/Linux)

3. Update a Client
helm upgrade --install bill .\k8s\charts\client-stack -n client-bill `
  --set clientId=bill --set baseDomain=demo.local

4. Check a Client’s Containers
kubectl get pods -n client-bill -o jsonpath="{range .items[*]}{.metadata.name}{': '}{range .spec.initContainers[*]}{.name}{' (init) '}{end}{range .spec.containers[*]}{.name}{' '}{end}{'\n'}{end}"

5. Stop (Suspend) One Client
helm upgrade --install bill .\k8s\charts\client-stack -n client-bill `
  --set clientId=bill --set baseDomain=emitit.local --set suspended=true

6. Resume One Client
helm upgrade --install bill .\k8s\charts\client-stack -n client-bill `
  --set clientId=bill --set baseDomain=emitit.local --set suspended=false

7. Get Password for phpMyAdmin (username root)
kubectl -n client-dodo exec deploy/bill-phpmyadmin -- printenv MYSQL_ROOT_PASSWORD

📝 Notes

Default phpmyadmin's username is root across all clients.

Use helm uninstall to fully remove a client’s stack.

Always update the Version Control table when changing this file.