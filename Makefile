CLUSTER := rollouts
K := kubectl -n rollouts
GO_IMAGE := golang:1.25-alpine
KUBECONFORM := ghcr.io/yannh/kubeconform:v0.7.0

.PHONY: cluster images deploy-naive deploy-safe deploy rollout bad-release undo down test lint check e2e

cluster: ## Create the kind cluster (1 control plane, 2 workers)
	kind create cluster --config cluster/kind.yaml --wait 120s
	kubectl wait --for=condition=Ready nodes --all --timeout=120s
	kubectl get nodes

images: ## Build the three releases and load them into the cluster
	docker build -q -t quote:v1 --build-arg VERSION=v1 app
	docker build -q -t quote:v2 --build-arg VERSION=v2 app
	docker build -q -t quote:v3-bad --build-arg VERSION=v3-bad --build-arg QUOTE_TOTAL=999 app
	kind load docker-image quote:v1 quote:v2 quote:v3-bad --name $(CLUSTER)
	docker images quote --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'

deploy-naive: ## Start fresh at v1 with deployment-naive.yaml (no readiness probe)
	$(MAKE) --no-print-directory deploy MANIFEST=k8s/deployment-naive.yaml

deploy-safe: ## Start fresh at v1 with deployment-safe.yaml (readiness probe, preStop)
	$(MAKE) --no-print-directory deploy MANIFEST=k8s/deployment-safe.yaml

deploy:
	kubectl apply -f k8s/namespace.yaml -f k8s/service.yaml
	$(K) delete deployment quote --ignore-not-found --wait
	$(K) wait --for=delete pod -l app=quote --timeout=90s
	kubectl apply -f $(MANIFEST)
	$(K) rollout status deployment/quote --timeout=120s
	scripts/wait-for-app.sh
	$(K) get pods -o wide

rollout: ## Roll to v2 while the probe counts failures (LABEL names the evidence file)
	scripts/measure-rollout.sh v2 $(or $(LABEL),rollout)

bad-release: ## Roll to v3-bad: healthy but wrong. The rollout is expected to stall.
	-scripts/measure-rollout.sh v3-bad bad-release 40s
	$(K) get pods

undo: ## Roll back to the last good version
	$(K) rollout undo deployment/quote
	$(K) rollout status deployment/quote --timeout=120s
	$(K) rollout history deployment/quote

down: ## Delete the cluster and everything in it
	kind delete cluster --name $(CLUSTER)

test: ## Go unit tests (in a container, no local Go needed)
	docker run --rm -v "$(CURDIR)/app:/src" -w /src $(GO_IMAGE) go test ./...

lint: ## Validate the Kubernetes files
	docker run --rm -v "$(CURDIR)/k8s:/k8s:ro" $(KUBECONFORM) -strict -summary /k8s

check: lint test ## What CI runs before the drill

e2e: ## The whole lab with checks, then delete the cluster
	scripts/e2e.sh
