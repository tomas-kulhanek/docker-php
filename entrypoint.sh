#!/bin/bash

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" || exit; /bin/pwd)"
INCLUDE_DIR="${SCRIPT_DIR%/}/$(basename "${SCRIPT_NAME}" .sh).d"

if [[ -d "${INCLUDE_DIR}" ]]; then
    while read -r file; do
        echo "Env: ${file}"

        while read -r line; do
            if [[ "${line}" == *'='* && ! "${line}" =~ ^\s*# ]]; then
                key="${line%%=*}"
                key="${key#"${key%%[![:space:]]*}"}"

                if [[ -z "${!key}" ]]; then
                    eval "export ${line}"
                fi
            fi
        done < "${file}"
    done < <(find "${INCLUDE_DIR}" -name '*.env' | sort)

    while read -r file; do
        echo "Init: ${file}"
        /bin/bash "${file}"
    done < <(find "${INCLUDE_DIR}" -name "*.sh" | sort)
fi

exec "$@"
