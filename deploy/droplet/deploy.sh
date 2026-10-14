#!/usr/bin/env bash
# Deploy (or roll back) OpenTrust on the server. Run as the `deployer` user, never as root.
#
#   ~/opentrust/deploy/droplet/deploy.sh             # latest of the default branch
#   ~/opentrust/deploy/droplet/deploy.sh <git-sha>   # a specific commit (rollback)
#
# Steps: fetch code -> build the images, tagged with the commit -> start -> wait for the site to be healthy.
# If the new version is not healthy, it goes back to the previous images and exits non-zero.
# Migrations don't roll back when you deploy an older commit. Check before rolling back past one.
set -euo pipefail

# The whole script lives in a function that bash reads completely before running anything: `git checkout` below can
# rewrite this very file, and bash reads plain scripts incrementally, which would break a run in progress.
main() {
  # shellcheck source=lib.sh
  . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

  if [ "$(id -u)" -eq 0 ]; then echo "Run this as the 'deployer' user, not root." >&2; exit 1; fi
  if [ ! -r "$ENV_FILE" ]; then echo "Cannot read $ENV_FILE (see deploy/droplet/.env.example)." >&2; exit 1; fi

  local repo_dir target previous_sha current branch project
  # A second deployment on the same server (e.g. staging) sets COMPOSE_PROJECT_NAME in its own env file; its images get their own names.
  project="$(envval COMPOSE_PROJECT_NAME)"; project="${project:-opentrust}"
  repo_dir="$(cd "$KIT_DIR/../.." && pwd)"
  target="${1:-}"
  cd "$repo_dir"
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "The working tree has local changes; refusing to deploy over them." >&2; exit 1
  fi

  previous_sha="$(git rev-parse --short HEAD)"
  git fetch --prune origin
  if [ -n "$target" ]; then
    git checkout --detach "$target"
  else
    # Return to the default branch first: a previous rollback leaves the checkout on a detached commit.
    branch="$(envval DEPLOY_BRANCH)"
    [ -z "$branch" ] && branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null | sed 's#^origin/##' || true)"
    branch="${branch:-main}"
    git checkout "$branch"
    git pull --ff-only origin "$branch"
  fi
  current="$(git rev-parse --short HEAD)"
  log "Deploying $current (was $previous_sha)"
  cd "$KIT_DIR"

  if [ "$(envval ENTRY)" != caddy ] && [ -z "$(envval CLOUDFLARE_TUNNEL_TOKEN)" ]; then
    echo "ENTRY is 'tunnel' (the default) but CLOUDFLARE_TUNNEL_TOKEN is empty in $ENV_FILE. Create the tunnel (docs, section 6) or set ENTRY=caddy." >&2
    exit 1
  fi

  local -a flags build_services
  flags=(); while IFS= read -r f; do flags+=("$f"); done < <(profile_flags)
  build_services=(web)
  local shopify=no
  if [ "$(envval RUN_SHOPIFY)" = yes ]; then shopify=yes; build_services+=(shopify); fi

  cp images.env images.env.prev
  { echo "WEB_IMAGE=$project-web:$current"; [ "$shopify" = yes ] && echo "SHOPIFY_IMAGE=$project-shopify:$current"; true; } > images.env

  log "building ${build_services[*]} (the first build takes several minutes)"
  if ! dc "${flags[@]}" build "${build_services[@]}"; then
    cp images.env.prev images.env
    notify "❌ Deploy of $current failed to BUILD. Nothing changed: the previous version is still running."
    echo "Build failed. Nothing was changed: the previous version is still running." >&2
    exit 1
  fi

  log "starting"
  dc "${flags[@]}" up -d --remove-orphans

  local healthy=no cid status
  for _ in $(seq 1 "${HEALTH_TRIES:-40}"); do   # default ~3.5 minutes: the first start also runs database migrations
    cid="$(dc ps -q web || true)"
    if [ -n "$cid" ]; then
      # shellcheck disable=SC2086
      status="$($DOCKER inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2> /dev/null || true)"
      if [ "$status" = healthy ]; then healthy=yes; break; fi
    fi
    sleep 5
  done

  if [ "$healthy" = yes ]; then
    log "web is healthy: $project-web:$current"
    # Keep the newest 3 images of each (current, previous and one spare for a rollback), remove the rest.
    for repo in "$project-web" "$project-shopify"; do
      # shellcheck disable=SC2086
      $DOCKER images "$repo" --format '{{.Tag}}' | tail -n +4 | while read -r tag; do $DOCKER rmi "$repo:$tag" > /dev/null 2>&1 || true; done
    done
    notify "✅ Deployed $current (was $previous_sha). To roll back: deploy.sh $previous_sha"
    if [ "$previous_sha" != "$current" ]; then
      log "Deployed $current. To roll back: $KIT_DIR/deploy.sh $previous_sha"
    else
      log "Deployed $current."
    fi
    return 0
  fi

  notify "❌ Deploy of $current did NOT become healthy; rolling back to $previous_sha (check the server logs)."
  log "web did NOT become healthy; last log lines:"
  dc logs --tail 40 web || true
  if [ -s images.env.prev ]; then
    log "rolling back to $previous_sha"
    cp images.env.prev images.env
    cd "$repo_dir" && git checkout --detach "$previous_sha" && cd "$KIT_DIR"
    local -a prev_flags=(--profile "$(envval ENTRY)")
    [ -z "$(envval ENTRY)" ] && prev_flags=(--profile tunnel)
    grep -q '^SHOPIFY_IMAGE=' images.env && prev_flags+=(--profile shopify)
    dc "${prev_flags[@]}" up -d --remove-orphans
  fi
  return 1
}

main "$@"
exit $?
