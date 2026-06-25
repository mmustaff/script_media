#!/usr/bin/env bash
set -euo pipefail

PATCH_ROOT="debian/patches"
SERIES_FILE="${PATCH_ROOT}/series"
DRY_RUN=0
SUBFOLDER_FILTER=""
SERIES_ORDER="backport,debian,intel"
APPLY_SERIES_ORDER=1

usage() {
	cat <<'EOF'
Usage: ./renumber_patches.sh [options]

Run this script from the repository root. It will:
  1. Renumber patch files sequentially inside each subfolder of debian/patches
  2. Regenerate debian/patches/series to match the new names and group order

Options:
  -n, --dry-run                    Show planned changes without writing files
  -s, --subfolder <name[,name...]> Renumber only selected subfolder(s)
                                   Example: --subfolder intel --subfolder debian,backport
  -o, --series-order <csv>         Series group order (default: backport,debian,intel)
                                   Unlisted groups are appended alphabetically
			--skip-series-order          Keep existing folder order from current series/file discovery
  -h, --help                       Show this help text
EOF
}

append_csv_items() {
	local csv="$1"
	local value
	IFS=',' read -r -a _items <<< "${csv}"
	for value in "${_items[@]}"; do
		value="${value//[[:space:]]/}"
		[[ -z "${value}" ]] && continue
		if [[ -n "${SUBFOLDER_FILTER}" ]]; then
			SUBFOLDER_FILTER+="${value},"
		else
			SUBFOLDER_FILTER="${value},"
		fi
	done
}

contains_csv_item() {
	local csv="$1"
	local needle="$2"
	[[ ",${csv}," == *",${needle},"* ]]
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-n|--dry-run)
			DRY_RUN=1
			shift
			;;
		-s|--subfolder)
			if [[ $# -lt 2 ]]; then
				echo "Error: --subfolder requires an argument." >&2
				exit 1
			fi
			append_csv_items "$2"
			shift 2
			;;
		-o|--series-order)
			if [[ $# -lt 2 ]]; then
				echo "Error: --series-order requires an argument." >&2
				exit 1
			fi
			SERIES_ORDER="$2"
			APPLY_SERIES_ORDER=1
			shift 2
			;;
		--skip-series-order)
			APPLY_SERIES_ORDER=0
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
	echo "Error: current directory is not inside a git repository." >&2
	exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
current_dir="$(pwd -P)"
repo_root_real="$(cd "${repo_root}" && pwd -P)"

if [[ "${current_dir}" != "${repo_root_real}" ]]; then
	echo "Error: run this script from the repository root: ${repo_root_real}" >&2
	exit 1
fi

if [[ ! -d "${PATCH_ROOT}" ]]; then
	echo "Error: patch directory not found: ${PATCH_ROOT}" >&2
	exit 1
fi

if [[ ! -f "${SERIES_FILE}" ]]; then
	echo "Error: series file not found: ${SERIES_FILE}" >&2
	exit 1
fi

shopt -s nullglob

declare -A dir_seen=()
declare -A listed_seen=()
declare -A rename_old_to_tmp=()
declare -A rename_tmp_to_new=()
declare -A series_by_dir=()
declare -A actual_by_dir=()
declare -A new_series_by_dir=()
declare -A selected_dir=()
declare -a dir_order=()
declare -a patch_dirs=()
declare -a series_dir_order=()

if [[ -n "${SUBFOLDER_FILTER}" ]]; then
	declare -a filtered_dirs=()
	IFS=',' read -r -a _dirs <<< "${SUBFOLDER_FILTER%,}"
	for dir_name in "${_dirs[@]}"; do
		dir_name="${dir_name//[[:space:]]/}"
		[[ -z "${dir_name}" ]] && continue
		selected_dir["${dir_name}"]=1
	done

	if [[ ${#selected_dir[@]} -eq 0 ]]; then
		echo "Error: no valid subfolder names were provided to --subfolder." >&2
		exit 1
	fi
fi

add_dir_once() {
	local dir="$1"
	if [[ -z "${dir_seen["${dir}"]+x}" ]]; then
		dir_seen["${dir}"]=1
		dir_order+=("${dir}")
	fi
}

add_unique_entry() {
	local key="$1"
	local value="$2"
	local current="${listed_seen["${key}"]:-}"

	if [[ ",${current}," == *",${value},"* ]]; then
		return
	fi

	if [[ -n "${current}" ]]; then
		listed_seen["${key}"]+="${value},"
	else
		listed_seen["${key}"]="${value},"
	fi
}

while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
	line="${raw_line%$'\r'}"

	[[ -z "${line//[[:space:]]/}" ]] && continue
	[[ "${line}" =~ ^[[:space:]]*# ]] && continue

	patch_rel="${line%%[[:space:]]*}"
	if [[ "${patch_rel}" != */* ]]; then
		continue
	fi

	dir_name="${patch_rel%/*}"
	base_name="${patch_rel##*/}"
	patch_path="${PATCH_ROOT}/${patch_rel}"

	if [[ ! -f "${patch_path}" ]]; then
		echo "Warning: skipping missing series entry ${patch_rel}" >&2
		continue
	fi

	add_dir_once "${dir_name}"
	series_by_dir["${dir_name}"]+="${base_name}"$'\n'
done < "${SERIES_FILE}"

selected_match_count=0
while IFS= read -r dir_name; do
	patch_dirs+=("${dir_name}")
	add_dir_once "${dir_name}"
	if [[ -n "${SUBFOLDER_FILTER}" && -n "${selected_dir["${dir_name}"]+x}" ]]; then
		selected_match_count=$((selected_match_count + 1))
	fi
	done < <(find "${PATCH_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%P\n' | LC_ALL=C sort)

if [[ ${#patch_dirs[@]} -eq 0 ]]; then
	echo "No patch subfolders found under ${PATCH_ROOT}" >&2
	exit 1
fi

if [[ -n "${SUBFOLDER_FILTER}" && ${selected_match_count} -eq 0 ]]; then
	echo "No matching patch subfolders found under ${PATCH_ROOT} for filter: ${SUBFOLDER_FILTER%,}" >&2
	exit 1
fi

for dir_name in "${patch_dirs[@]}"; do
	while IFS= read -r base_name; do
		[[ -z "${base_name}" ]] && continue
		actual_by_dir["${dir_name}"]+="${base_name}"$'\n'
	done < <(find "${PATCH_ROOT}/${dir_name}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | LC_ALL=C sort)
done

for dir_name in "${dir_order[@]}"; do
	ordered_names=()

	while IFS= read -r base_name; do
		[[ -z "${base_name}" ]] && continue
		ordered_names+=("${base_name}")
		add_unique_entry "${dir_name}" "${base_name}"
	done <<< "${series_by_dir["${dir_name}"]:-}"

	while IFS= read -r base_name; do
		[[ -z "${base_name}" ]] && continue
		if [[ ",${listed_seen["${dir_name}"]:-}," == *",${base_name},"* ]]; then
			continue
		fi
		ordered_names+=("${base_name}")
		add_unique_entry "${dir_name}" "${base_name}"
	done <<< "${actual_by_dir["${dir_name}"]:-}"

	if [[ ${#ordered_names[@]} -eq 0 ]]; then
		continue
	fi

	index=1
	for old_base in "${ordered_names[@]}"; do
		if [[ -z "${SUBFOLDER_FILTER}" || -n "${selected_dir["${dir_name}"]+x}" ]]; then
			if [[ "${old_base}" =~ ^[0-9]{4}-(.+)$ ]]; then
				suffix="${BASH_REMATCH[1]}"
			else
				suffix="${old_base}"
			fi
			new_base="$(printf '%04d-%s' "${index}" "${suffix}")"
		else
			new_base="${old_base}"
		fi
		new_series_by_dir["${dir_name}"]+="${dir_name}/${new_base}"$'\n'

		if [[ "${old_base}" != "${new_base}" ]]; then
			old_path="${PATCH_ROOT}/${dir_name}/${old_base}"
			tmp_path="${PATCH_ROOT}/${dir_name}/.renumber.$$.$index.${old_base}"
			new_path="${PATCH_ROOT}/${dir_name}/${new_base}"
			rename_old_to_tmp["${old_path}"]="${tmp_path}"
			rename_tmp_to_new["${tmp_path}"]="${new_path}"
		fi

		index=$((index + 1))
	done
done

new_series_content=""
if [[ ${APPLY_SERIES_ORDER} -eq 1 ]]; then
	IFS=',' read -r -a order_groups <<< "${SERIES_ORDER}"
	for dir_name in "${order_groups[@]}"; do
		dir_name="${dir_name//[[:space:]]/}"
		[[ -z "${dir_name}" ]] && continue
		if [[ -n "${new_series_by_dir["${dir_name}"]:-}" ]]; then
			series_dir_order+=("${dir_name}")
		fi
	done

	for dir_name in "${dir_order[@]}"; do
		if [[ -z "${new_series_by_dir["${dir_name}"]:-}" ]]; then
			continue
		fi
		if contains_csv_item "${SERIES_ORDER}" "${dir_name}"; then
			continue
		fi
		series_dir_order+=("${dir_name}")
	done
else
	series_dir_order=("${dir_order[@]}")
fi

for dir_name in "${series_dir_order[@]}"; do
	if [[ -n "${new_series_by_dir["${dir_name}"]:-}" ]]; then
		new_series_content+="${new_series_by_dir["${dir_name}"]}"
	fi
done
new_series_content="${new_series_content%$'\n'}"

echo "Repository root : ${repo_root_real}"
echo "Patch root      : ${PATCH_ROOT}"
echo "Series file     : ${SERIES_FILE}"
if [[ -n "${SUBFOLDER_FILTER}" ]]; then
	echo "Subfolder filter: ${SUBFOLDER_FILTER%,}"
fi
if [[ ${APPLY_SERIES_ORDER} -eq 1 ]]; then
	echo "Series order    : ${SERIES_ORDER}"
else
	echo "Series order    : disabled (--skip-series-order)"
fi
echo

rename_count=0
rename_count=${#rename_old_to_tmp[@]}
if [[ ${rename_count} -gt 0 ]]; then
	while IFS= read -r old_path; do
		tmp_path="${rename_old_to_tmp["${old_path}"]}"
		new_path="${rename_tmp_to_new["${tmp_path}"]}"
		echo "rename: ${old_path#${PATCH_ROOT}/} -> ${new_path#${PATCH_ROOT}/}"
	done < <(printf '%s\n' "${!rename_old_to_tmp[@]}" | LC_ALL=C sort)
fi

if [[ ${rename_count} -eq 0 ]]; then
	echo "No patch file renames are required."
fi

echo
echo "Updated series content:"
printf '%s\n' "${new_series_content}"

if [[ ${DRY_RUN} -eq 1 ]]; then
	echo
	echo "Dry run only. No files were changed."
	exit 0
fi

for old_path in "${!rename_old_to_tmp[@]}"; do
	mv -- "${old_path}" "${rename_old_to_tmp["${old_path}"]}"
done

for tmp_path in "${!rename_tmp_to_new[@]}"; do
	mv -- "${tmp_path}" "${rename_tmp_to_new["${tmp_path}"]}"
done

printf '%s\n' "${new_series_content}" > "${SERIES_FILE}"

echo
echo "Renumbering complete."