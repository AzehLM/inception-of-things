#!/bin/bash
set -eo pipefail

GITLAB_URL="http://localhost:8081"
GITLAB_INTERNAL_URL="http://gitlab.gitlab.svc.cluster.local"
PROJECT_NAME="p3-bonus"
TOKEN_NAME="bootstrap-argocd"
WIL_APP_MANIFESTS="./confs/manifests/wil-app"
APP_MANIFEST="./confs/manifests/application.yml"

echo "[bootstrap] checking if GitLab is reachable..."
if ! curl -sf -o /dev/null "$GITLAB_URL/users/sign_in"; then
  echo "GitLab isn't reachable on $GITLAB_URL. Run 'make setup' first." >&2
  exit 1
fi

# Generating root token with gitlab-rails
# https://docs.gitlab.com/administration/operations/rails_console/
echo "[bootstrap] creating a personal access token for root..."
TOKEN=$(kubectl exec -n gitlab deploy/gitlab -- gitlab-rails runner "
  u = User.find_by(username: 'root')
  u.personal_access_tokens.where(name: '$TOKEN_NAME').destroy_all
  t = u.personal_access_tokens.create(
    scopes: %w[api read_repository write_repository],
    name: '$TOKEN_NAME',
    expires_at: 365.days.from_now
  )
  t.save!
  puts t.token
" 2>/dev/null | tail -1)

if [[ -z "$TOKEN" || "$TOKEN" != glpat-* ]]; then
  echo "Failed to generate a GitLab token." >&2
  exit 1
fi
echo "[bootstrap] token generated."

# Check and create project if it doesn't exist using GitLab API
echo "[bootstrap] checking if project '$PROJECT_NAME' exists..."
PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/projects?search=$PROJECT_NAME" | jq -r ".[] | select(.path==\"$PROJECT_NAME\") | .id")

if [[ -z "$PROJECT_ID" ]]; then
  echo "[bootstrap] creating project '$PROJECT_NAME'..."
  PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" -X POST \
    --data "name=$PROJECT_NAME&visibility=private&initialize_with_readme=false" \
    "$GITLAB_URL/api/v4/projects" | jq -r ".id")
  NEEDS_PUSH=true
else
  echo "[bootstrap] project '$PROJECT_NAME' already exists (id=$PROJECT_ID)"
  COMMIT_COUNT=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
    "$GITLAB_URL/api/v4/projects/$PROJECT_ID/repository/commits?per_page=1" | jq 'length' 2>/dev/null || echo 0)
  if [[ "$COMMIT_COUNT" -eq 0 ]]; then
    echo "[bootstrap] repo is empty, will push initial manifests"
    NEEDS_PUSH=true
  else
    echo "[bootstrap] repo already has commits, leaving it untouched (preserving any manual changes)"
    NEEDS_PUSH=false
  fi
fi

# Pushing deployment and service manifests
if [[ "$NEEDS_PUSH" == true ]]; then
  echo "[bootstrap] pushing manifests..."
  WORKDIR=$(mktemp -d)
  cp "$WIL_APP_MANIFESTS"/*.yml "$WORKDIR/"
  cd "$WORKDIR"
  git init -q
  git config user.email "bootstrap@iot.local"
  git config user.name "bootstrap-script"
  git add .
  git commit -q -m "wil-app manifests"
  git branch -M main
  git remote add origin "http://root:${TOKEN}@localhost:8081/root/${PROJECT_NAME}.git"
  git push -q origin main
  cd - > /dev/null
  rm -rf "$WORKDIR"
  echo "[bootstrap] manifests pushed."
else
  echo "[bootstrap] skipping push."
fi

# Using k8s secret for Argo CD watching Gitlab repository, Gitlab becomes the source of truth
echo "[bootstrap] wiring Argo CD repo credentials..."
kubectl create secret generic gitlab-p3-repo -n argocd \
  --from-literal=type=git \
  --from-literal=url="$GITLAB_INTERNAL_URL/root/${PROJECT_NAME}.git" \
  --from-literal=username=root \
  --from-literal=password="$TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label secret gitlab-p3-repo -n argocd argocd.argoproj.io/secret-type=repository --overwrite

# Applying Argo CD manifest
echo "[bootstrap] applying Argo CD application..."
kubectl apply -f "$APP_MANIFEST"

echo "[bootstrap] forcing refresh..."
kubectl patch application p3-gitlab -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Allowing 30 retries for the sync - 180s
echo "[bootstrap] waiting for sync to create wil-app in 'dev'..."
MAX_RETRIES=30
i=0
until kubectl get svc wil-app -n dev &> /dev/null; do
  i=$((i+1))
  if [[ $i -ge $MAX_RETRIES ]]; then
    echo "[bootstrap] ERROR: wil-app never appeared in 'dev' after 3min." >&2
    echo "[bootstrap] Check Argo CD sync status:" >&2
    kubectl get application p3-gitlab -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}' >&2
    echo "[bootstrap] Check repo-server logs: kubectl logs -n argocd deploy/argocd-repo-server" >&2
    exit 1
  fi
  sleep 6
done
kubectl wait --for=condition=available --timeout=180s deployment/wil-app -n dev

echo
echo "Bootstrap complete."
echo "wil-app: http://localhost:8888"
