#!/bin/bash
# Autopilot: keeps iglass's automation going, and says so when it needs a person. The Autopilot
# workflow runs it every day, and when a push to main changes the version.
#
#  1. Publishes the release for a new version in bin/iglass; the Release workflow then updates
#     Homebrew and the portfolio.
#  2. Runs the Release workflow again when Homebrew or the portfolio are behind the latest release.
#  3. Turns back on workflows GitHub switched off for inactivity, and deletes the branches of
#     merged PRs (GitHub does that by itself only when a person merges).
#  4. Checks the latest runs of CI, Release and Website, that the weekly CI run happens, and
#     that PRs from bots don't get stuck.
#  5. Keeps one issue, labelled autopilot, open while something needs a person, and closes it
#     once everything is fine again.
#
# Needs: gh with GH_TOKEN (contents, actions and issues: write), jq, git with full history.
# DRY_RUN=1 reports what it would do and changes nothing.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo=${GITHUB_REPOSITORY:-vukkt/iglass}
run_url="${GITHUB_SERVER_URL:-https://github.com}/$repo/actions/runs/${GITHUB_RUN_ID:-0}"
dry=${DRY_RUN:-}
now=$(date -u +%s)
problems=()
actions=()

problem() { problems+=("$1"); echo "Needs a person: $1"; }
did() { actions+=("$1"); echo "Did: $1"; }
act() { if [[ -n "$dry" ]]; then echo "(dry run) $*"; else "$@"; fi; }
hours_since() {
  local t
  t=$(date -u -d "$1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s)
  echo $(((now - t) / 3600))
}

# 1. A version without a release: publish it. Its title comes from the commit that set the
# version, the merged PR: "Warp support (1.6.0) (#10)" → "iglass 1.6.0: Warp support".
version=$(sed -n 's/^IGLASS_VERSION="\(.*\)"$/\1/p' "$root/bin/iglass")
[[ -n "$version" ]] || { echo "No IGLASS_VERSION in bin/iglass." >&2; exit 1; }
tag="v$version"
published_now=
if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  echo "Release $tag exists."
else
  commit=$(git -C "$root" log -1 --format=%H -S"IGLASS_VERSION=\"$version\"" -- bin/iglass)
  commit=${commit:-$(git -C "$root" rev-parse HEAD)}
  subject=$(git -C "$root" log -1 --format=%s "$commit" |
    sed -E -e 's/ \(#[0-9]+\)$//' -e 's/ \(v?[0-9]+\.[0-9]+\.[0-9]+\)$//')
  notes=$("$root/tools/release-notes.sh" "$version")
  act gh release create "$tag" --repo "$repo" --target "$commit" \
    --title "iglass $version: $subject" --notes "$notes"
  # A release published with the workflow's token starts no workflows by itself.
  act gh workflow run release.yml --repo "$repo" --ref main -f tag="$tag"
  did "Published [$tag](https://github.com/$repo/releases/tag/$tag) (\"iglass $version: $subject\") and started the Release workflow for it."
  published_now=1
fi

# 2. Homebrew and the portfolio show the latest release. Give a release's own Release run two
# hours; after that, run it again (it changes only what's behind); after two days, ask.
if [[ -z "$published_now" ]]; then
  IFS=$'\t' read -r latest title published < <(gh release view --repo "$repo" \
    --json tagName,name,publishedAt --jq '[.tagName, .name, .publishedAt] | @tsv')
  age=$(hours_since "$published")
  tap=$(curl -fsSL https://raw.githubusercontent.com/vukkt/homebrew-tap/main/Formula/iglass.rb |
    sed -n 's|^  url ".*/archive/refs/tags/\(v[^"]*\)\.tar\.gz"$|\1|p')
  want=$("$root/tools/portfolio-release.sh" --line "$latest" "$title" "$published")
  has=$(curl -fsSL https://raw.githubusercontent.com/vukkt/vuk-portfolio/main/.skills/vuk-portfolio/data/portfolio_content.json |
    jq -r '.hero.glance[] | select(.label == "Latest release") | .value')
  behind=()
  [[ "$tap" == "$latest" ]] || behind+=("Homebrew has ${tap:-nothing}")
  [[ "$has" == "$want" ]] || behind+=("the portfolio says \"$has\"")
  if ((${#behind[@]} == 0)); then
    echo "Homebrew and the portfolio show $latest."
  elif ((age < 2)); then
    echo "$latest is $age h old; its Release run has time to finish."
  elif ((age > 48)); then
    problem "$latest is out for $age hours, but ${behind[*]}. The [Release runs](https://github.com/$repo/actions/workflows/release.yml) say why."
  elif [[ -n "$(gh run list --repo "$repo" --workflow release.yml --json status \
    --jq '[.[] | select(.status != "completed")] | .[0].status // empty')" ]]; then
    echo "A Release run is under way."
  else
    act gh workflow run release.yml --repo "$repo" --ref main -f tag="$latest"
    did "${behind[*]} instead of $latest; started the Release workflow again."
  fi
fi

# 3. Workflows GitHub switched off after 60 days without activity. One switched off by hand
# stays off.
while read -r id name; do
  [[ -n "$id" ]] || continue
  act gh api -X PUT "repos/$repo/actions/workflows/$id/enable"
  did "Turned the $name workflow back on (GitHub had switched it off for inactivity)."
done < <(gh api "repos/$repo/actions/workflows" \
  --jq '.workflows[] | select(.state == "disabled_inactivity") | "\(.id) \(.name)"')

# Branches of merged PRs: GitHub deletes them by itself only when a person merges, not a bot.
# A branch with an open PR, or with no PR at all, stays.
while read -r branch; do
  [[ -n "$branch" && "$branch" != main ]] || continue
  state=$(gh pr list --repo "$repo" --head "$branch" --state all --limit 5 --json state \
    --jq 'if any(.[]; .state == "OPEN") then "OPEN" else (.[0].state // "") end')
  [[ "$state" == MERGED ]] || continue
  act gh api -X DELETE "repos/$repo/git/refs/heads/$branch" --silent
  did "Deleted the branch $branch: its PR is merged."
done < <(gh api "repos/$repo/branches" --paginate --jq '.[].name')

# 4. The latest finished run of each workflow (a run cancelled by a newer one doesn't count).
for wf in ci.yml release.yml pages.yml; do
  IFS=$'\t' read -r conclusion url name < <(gh run list --repo "$repo" --workflow "$wf" --limit 10 \
    --json conclusion,status,url,workflowName,headBranch --jq '[.[] | select(.status == "completed"
      and .conclusion != "cancelled" and .conclusion != "skipped"
      and (.headBranch == "main" or (.headBranch | startswith("v"))))][0]
      | [.conclusion, .url, .workflowName] | @tsv') || true
  case ${conclusion:-none} in
    success | none) ;;
    *) problem "The last ${name:-$wf} run on main ended in $conclusion: $url" ;;
  esac
done

last_weekly=$(gh run list --repo "$repo" --workflow ci.yml --event schedule --limit 1 \
  --json createdAt --jq '.[0].createdAt // empty')
if [[ -n "$last_weekly" ]] && (($(hours_since "$last_weekly") > 8 * 24)); then
  problem "The weekly CI run last ran $last_weekly, more than 8 days ago."
fi

while IFS=$'\t' read -r url created who; do
  [[ -n "$url" ]] || continue
  (($(hours_since "$created") > 72)) && problem "A PR from $who has been open for over 3 days: $url"
done < <(gh pr list --repo "$repo" --state open --json url,createdAt,author \
  --jq '.[] | select(.author.is_bot or (.author.login | startswith("app/")))
    | [.url, .createdAt, .author.login] | @tsv')

# 5. The issue.
issue=$(gh issue list --repo "$repo" --label autopilot --state open --json number \
  --jq '.[0].number // empty')
summary() {
  local p a
  if ((${#problems[@]})); then
    echo "Autopilot found something it can't fix by itself:"
    echo
    for p in "${problems[@]}"; do echo "- $p"; done
  else
    echo "Everything is running."
  fi
  if ((${#actions[@]})); then
    echo
    echo "What it did:"
    echo
    for a in "${actions[@]}"; do echo "- $a"; done
  fi
  echo
  echo "From [this run]($run_url). Autopilot checks again every day and closes this issue once everything is fine."
}

if ((${#problems[@]})); then
  if [[ -n "$issue" ]]; then
    act gh issue edit "$issue" --repo "$repo" --body "$(summary)"
  else
    act gh issue create --repo "$repo" --title "Autopilot needs a hand" --label autopilot --body "$(summary)"
  fi
elif [[ -n "$issue" ]]; then
  act gh issue close "$issue" --repo "$repo" --comment "Everything is running again ([this run]($run_url))."
fi

summary
[[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || summary >>"$GITHUB_STEP_SUMMARY"
