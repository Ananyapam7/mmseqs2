#!/bin/sh -e

fail() {
    echo "Error: $1"
    exit 1
}

notExists() {
	[ ! -f "$1" ]
}

#pre processing
[ -z "$MMSEQS" ] && echo "Please set the environment variable \$MMSEQS to your MMSEQS binary." && exit 1;
# check number of input variables
[ "$#" -ne 4 ] && echo "Please provide <queryDB> <targetDB> <outDB> <tmp>" && exit 1;
# check if files exist
[ ! -f "$1.dbtype" ] && echo "$1.dbtype not found!" && exit 1;
[ ! -f "$2.dbtype" ] && echo "$2.dbtype not found!" && exit 1;
[   -f "$3.dbtype" ] && echo "$3.dbtype exists already!" && exit 1;
[ ! -d "$4" ] && echo "tmp directory $4 not found!" && mkdir -p "$4";

INPUT="$1"
TARGET="$2"
RESULTS="$3"
TMP_PATH="$4"

if [ ! -e "${TMP_PATH}/first.dbtype" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" search "${INPUT}" "${TARGET}" "${TMP_PATH}/first" "${TMP_PATH}/tmp_hsp1" ${SEARCH_PAR} \
        || fail "First search died"
fi

if [ ! -e "${TMP_PATH}/first_aln.dbtype" ]; then
    # shellcheck disable=SC2086
    $RUNNER "$MMSEQS" align "${INPUT}" "${TARGET}" "${TMP_PATH}/first" "${TMP_PATH}/first_aln" ${ALN1_PAR} \
        || fail "filterdb died"
fi

if [ ! -e "${TMP_PATH}/top1.dbtype" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" filterdb "${TMP_PATH}/first_aln" "${TMP_PATH}/top1" --extract-lines 1 ${THREADS_COMP_PAR} \
        || fail "filterdb died"
fi

if [ ! -e "${TMP_PATH}/top1_aln.dbtype" ]; then
    # shellcheck disable=SC2086
    $RUNNER "$MMSEQS" align "${INPUT}" "${TARGET}" "${TMP_PATH}/top1" "${TMP_PATH}/top1_aln" ${ALNTOP_PAR} \
        || fail "filterdb died"
fi

if [ ! -e "${TMP_PATH}/aligned.dbtype" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" extractalignedregion "${INPUT}" "${TARGET}" "${TMP_PATH}/top1_aln" "${TMP_PATH}/aligned" --extract-mode 2 ${THREADS_COMP_PAR} \
        || fail "extractalignedregion failed"
fi

if [ ! -e "${TMP_PATH}/first_sub" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" createsubdb "${TMP_PATH}/aligned" "${TMP_PATH}/first" "${TMP_PATH}/first_sub" --subdb-mode 1 ${VERBOSITY} \
        || fail "createsubdb"
fi

if [ ! -e "${TMP_PATH}/round2.dbtype" ]; then
    # shellcheck disable=SC2086
    $RUNNER "$MMSEQS" align "${TMP_PATH}/aligned" "${TARGET}" "${TMP_PATH}/first_sub" "${TMP_PATH}/round2" ${ALN2_PAR} \
        || fail "second align died"
fi

# Concat top hit from first search with all the results from second search
# We can use filterdb --beats-first to filter out all entries from second search that
# do not reach the evalue of the top 1 hit
if [ ! -e "${TMP_PATH}/merged.dbtype" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" mergedbs "${TMP_PATH}/top1_aln" "${TMP_PATH}/merged" "${TMP_PATH}/top1_aln" "${TMP_PATH}/round2" ${VERBOSITY} \
        || fail "mergedbs died"
fi

if [ ! -e "${TMP_PATH}/2b_ali.dbtype" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" filterdb "${TMP_PATH}/merged" "${TMP_PATH}/2b_ali" --beats-first --filter-column 4 --comparison-operator le ${THREADS_COMP_PAR} \
        || fail "filterdb died"
fi

if [ "${TAX_OUTPUT}" -eq "0" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" lca "${TARGET}" "${TMP_PATH}/2b_ali" "${RESULTS}" ${LCA_PAR} \
        || fail "Lca died"
elif [ "${TAX_OUTPUT}" -eq "2" ]; then
    # shellcheck disable=SC2086
    "$MMSEQS" lca "${TARGET}" "${TMP_PATH}/2b_ali" "${RESULTS}" ${LCA_PAR} \
        || fail "Lca died"
    # shellcheck disable=SC2086
    "$MMSEQS" mvdb "${TMP_PATH}/2b_ali" "${RESULTS}_aln" ${VERBOSITY} \
        || fail "mvdb died"
else
    # shellcheck disable=SC2086
    "$MMSEQS" mvdb "${TMP_PATH}/2b_ali" "${RESULTS}" ${VERBOSITY} \
        || fail "mvdb died"
fi


if [ -n "${REMOVE_TMP}" ]; then
    rm -rf "${TMP_PATH}/tmp_hsp1"

    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/first" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/first_aln" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/first_sub" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/top1" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/top1_aln" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/aligned" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/round2" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/merged" ${VERBOSITY}
    # shellcheck disable=SC2086
    "$MMSEQS" rmdb "${TMP_PATH}/2b_ali" ${VERBOSITY}

    rm -f "${TMP_PATH}/taxonomy.sh"
fi
