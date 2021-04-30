#!/usr/bin/env bash
set -euo pipefail

inputs=()
output=
output_file=out.md

usage() {
cat <<EOF
usage: ${0##*/} [-h] -o OUTFILE [-i FILE]...

    -h  display this help
    -i  input file path
    -o  output markdown file path
EOF
exit 1
}

urlencode() {
    for (( i = 0; i < "${#1}"; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
        *) printf '%%%02X' "'$c" ;;
        esac
    done
}

isurl() { [[ "$1" =~ https?://* ]]; }

writeout() { output="$output""$1"; }

parse_repo() {
    project="$1"
    repo="https://github.com/${project}"
    writeout "| $repo |"

    docker=0
    while read -r name; do
	if [[ "${name}" =~ [Dd]ocker ]]; then
	    docker=1
	fi
        encoded_name="$(urlencode "${name}")"
        writeout " ["
        writeout "![${name}](${repo}/workflows/${encoded_name}/badge.svg)"
        writeout "]"
        writeout "(${repo}/actions?query=workflow:\"${encoded_name}\")"
    done < <(curl -sL "https://api.github.com/repos/${1}/actions/workflows" | jq -r '.workflows[].name')

    if [ ${docker} -eq 1 ]; then
	repo_short="${project/\/docker-/\/}"
        writeout " [![Docker Build](https://img.shields.io/docker/cloud/build/${1})](https://hub.docker.com/r/${1})"
    fi
    
    writeout " [![GitHub PR](https://img.shields.io/github/issues-pr/${1}.svg)](https://GitHub.com/${1}/pulls)"
    
    writeout " |\n"
    echo " Generated markdown for $1"
}

[ "$#" -lt 4 ] && usage
command -v jq > /dev/null || { echo "Need jq"; exit 1; }

OPTIND=1
while getopts ":ho:i:" opt; do
    case $opt in
        i)
            inputs+=("$OPTARG")
            ;;
        o)
            output_file="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

[[ "$output_file" != *.md ]] && output_file="$output_file".md

tmpd="$(mktemp -d -t dashboardXXXX)"

writeout "| Repo | Actions |\n"
writeout "| --- | --- |\n"
for i in "${inputs[@]}"; do
    echo Generating markdown for "${i##*/}"...
    count=0
    while read -r line; do
        [[ "$line" = \#* ]] && continue
        [ -z "$line" ] && continue
        parse_repo "$line"
        count=$((count+1))
    done < <(if isurl "$i"; then curl -sL "$i"; else cat "$i"; fi)
    [ $count -eq 0 ] && { echo "Failed to read $i"; exit 1; }
    writeout "---\n\n"
done

echo -e "$output" > "$output_file"
echo Wrote to "$output_file"
rm -rf "$tmpd"
