.DEFAULT_GOAL	:= all

.PHONY: all
all: install setup bootstrap-gitlab

.PHONY: install
install:
	chmod +x scripts/install.sh
	./scripts/install.sh

.PHONY: setup
setup:
	chmod +x scripts/setup.sh
	./scripts/setup.sh

.PHONY: bootstrap-gitlab
bootstrap-gitlab:
	chmod +x scripts/bootstrap-gitlab.sh
	./scripts/bootstrap-gitlab.sh

.PHONY: reapply-gitlab
reapply-gitlab:
	echo "$(BOLD)$(BLUE)Reapplying GitLab manifests (no restart)$(NC)"
	kubectl apply -f confs/manifests/gitlab/service.yml
	kubectl apply -f confs/manifests/gitlab/pvc.yml

.PHONY: restart-gitlab
restart-gitlab:
	echo "$(BOLD)$(BLUE)Restarting GitLab (keeping PVCs, incremental reconfigure)$(NC)"
	kubectl apply -f confs/manifests/gitlab/deployment.yml
	kubectl rollout restart deployment/gitlab -n gitlab
	kubectl rollout status deployment/gitlab -n gitlab --timeout=600s

.PHONY: reset-gitlab
reset-gitlab:
	echo "$(BOLD)$(BLUE)Wiping GitLab (deployment + PVCs), keeping the rest of the cluster$(NC)"
	-kubectl delete deployment gitlab -n gitlab
	-kubectl delete pvc gitlab-config-pvc gitlab-data-pvc gitlab-logs-pvc -n gitlab
	kubectl apply -f confs/manifests/gitlab/pvc.yml
	kubectl apply -f confs/manifests/gitlab/deployment.yml
	kubectl wait --for=condition=available --timeout=1500s deployment/gitlab -n gitlab
	pkill -f "port-forward svc/gitlab" 2>/dev/null || true
	nohup kubectl port-forward svc/gitlab -n gitlab 8081:80 &> /tmp/pf-gitlab.log &
	sleep 2
	echo "GitLab port-forward restarted on :8081"

.PHONY: expose-gitlab
expose-gitlab:
	pkill -f "port-forward svc/gitlab" 2>/dev/null || true
	nohup kubectl port-forward svc/gitlab -n gitlab 8081:80 &> /tmp/pf-gitlab.log &
	sleep 2
	curl -sf -o /dev/null http://localhost:8081/users/sign_in && echo "GitLab reachable on :8081" || echo "GitLab still not reachable, check pod status"

.PHONY: logs-gitlab
logs-gitlab:
	kubectl logs -n gitlab -l app=gitlab -f

.PHONY: logs-argocd
logs-argocd:
	kubectl logs -n argocd deploy/argocd-repo-server -f

.PHONY: fclean
fclean:
	@k3d cluster delete iot-cluster

.PHONY: re
re: fclean all

BLUE   := \033[0;34m
BOLD   := \033[1m
NC     := \033[0m
