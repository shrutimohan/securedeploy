#!/usr/bin/env bash
# Proves the deploy gate rejects an UNSIGNED image. Run from your laptop (needs AWS creds, docker, cosign).
# Usage: ./scripts/demo-unsigned.sh <region> <account-id>
set -euo pipefail
REGION=${1:?region}; ACCT=${2:?account id}
REPO="$ACCT.dkr.ecr.$REGION.amazonaws.com/securedeploy-api"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCT.dkr.ecr.$REGION.amazonaws.com"
docker build -t "$REPO:unsigned-$(date +%s)" app/api
docker push --all-tags "$REPO" >/dev/null
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$(docker images --format '{{.Repository}}:{{.Tag}}' "$REPO" | grep unsigned | head -1)")
echo "Unsigned image: $DIGEST"
echo "--- cosign verify (EXPECTED TO FAIL) ---"
cosign verify --certificate-identity-regexp "^https://github.com/.*/.github/workflows/build.yml@.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com "$DIGEST" || echo ">>> REJECTED: no valid signature"
echo
echo "Now run the 'deploy' workflow manually (Actions tab) with api_image=$DIGEST and watch it fail at 'Cosign verify'."
