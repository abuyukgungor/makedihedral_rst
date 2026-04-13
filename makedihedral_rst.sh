#!/usr/bin/env bash

usage() {
    echo "Usage: $0 -i <protein.pdb> -r <1,2,3,4,5> -o <output.dat> [-c <A,B>] [-p <parameters_file.txt>] [-e <other_restraints.dat>]"
    exit 1
}

TARGET_CHAINS=""
OTHER_RESTRAINTS_FILE=""
PARAMS_FILE=""

while getopts "i:r:o:c:e:p:" opt; do
    case ${opt} in
        i ) PDB_FILE=$OPTARG ;;
        r ) RES_LIST=$OPTARG ;;
        o ) OUT_FILE=$OPTARG ;;
        c ) TARGET_CHAINS=$OPTARG ;;
        p ) PARAMS_FILE=$OPTARG ;;
        e ) OTHER_RESTRAINTS_FILE=$OPTARG ;;
        * ) usage ;;
    esac
done

if [ -z "$PDB_FILE" ] || [ -z "$RES_LIST" ] || [ -z "$OUT_FILE" ]; then
    usage
fi

if [ ! -f "$PDB_FILE" ]; then
    echo "Error: File $PDB_FILE not found!"
    exit 1
fi

if [ -n "$OTHER_RESTRAINTS_FILE" ] && [ ! -f "$OTHER_RESTRAINTS_FILE" ]; then
    echo "Warning: Other restraints file '$OTHER_RESTRAINTS_FILE' not found. It will be ignored." >&2
    OTHER_RESTRAINTS_FILE=""
fi

# Parameters
RESTRAINT_PARAMS="r1=90., r2=160., r3=200., r4=280., rk2 = 50., rk3=50.,"

if [ -n "$PARAMS_FILE" ]; then
    if [ -f "$PARAMS_FILE" ]; then
        RESTRAINT_PARAMS=$(cat "$PARAMS_FILE")
    else
        echo "Error: Parameter file '$PARAMS_FILE' not found!"
        exit 1
    fi
fi

declare -A N_idx CA_idx C_idx res_names

# PDB reading section
while IFS= read -r line; do
    if [[ "$line" == ATOM* ]]; then
        atom_id="${line:6:5}"
        atom_name="${line:12:4}"
        res_name="${line:17:3}"
        chain_id="${line:21:1}"
        res_num="${line:22:4}"

        atom_id="${atom_id// /}"
        atom_name="${atom_name// /}"
        res_name="${res_name// /}"
        chain_id="${chain_id// /}"
        res_num="${res_num// /}"

        if [ -n "$TARGET_CHAINS" ]; then
            if [[ ! ",$TARGET_CHAINS," == *",$chain_id,"* ]]; then
                continue
            fi
            uniq_key="${chain_id}${res_num}"
        else
            uniq_key="${res_num}"
        fi

        res_names[$uniq_key]=$res_name
        if [[ "$atom_name" == "N" ]];  then N_idx[$uniq_key]=$atom_id; fi
        if [[ "$atom_name" == "CA" ]]; then CA_idx[$uniq_key]=$atom_id; fi
        if [[ "$atom_name" == "C" ]];  then C_idx[$uniq_key]=$atom_id; fi
    fi
done < "$PDB_FILE"

IFS=',' read -ra RAW_RES_ADDR <<< "$RES_LIST"
RES_ADDR=()

for item in "${RAW_RES_ADDR[@]}"; do
    item="${item// /}"
    
    if [[ "$item" == *":"* ]]; then
        start="${item%:*}"
        end="${item#*:}"
        for (( j=start; j<=end; j++ )); do
            RES_ADDR+=("$j")
        done
    else
        if [ -n "$item" ]; then
            RES_ADDR+=("$item")
        fi
    fi
done

if [ -n "$TARGET_CHAINS" ]; then
    IFS=',' read -ra CHAIN_ADDR <<< "$TARGET_CHAINS"
else
    CHAIN_ADDR=("")
fi

first_restraint_written=0

{
    for chain in "${CHAIN_ADDR[@]}"; do
        chain="${chain// /}"
        
        for i in "${RES_ADDR[@]}"; do
            i="${i// /}"

            curr_key="${chain}${i}"
            prev_key="${chain}$((i - 1))"
            next_key="${chain}$((i + 1))"

            if [[ -z "${res_names[$curr_key]}" ]]; then
                continue
            fi

            res3="${res_names[$curr_key]}"
            label="${res3}${i}"

            # Calculate PHI Angle
            if [[ -n "${C_idx[$prev_key]}" && -n "${N_idx[$curr_key]}" && -n "${CA_idx[$curr_key]}" && -n "${C_idx[$curr_key]}" ]]; then
                echo "#  $label PHI"
                if [ "$first_restraint_written" -eq 0 ]; then
                    printf " &rst iat=%s,%s,%s,%s, \n" "${C_idx[$prev_key]}" "${N_idx[$curr_key]}" "${CA_idx[$curr_key]}" "${C_idx[$curr_key]}"
                    printf "   %s  &end\n" "$RESTRAINT_PARAMS"
                    echo "#"
                    first_restraint_written=1
                else
                    printf " &rst iat=%s,%s,%s,%s, &end\n" "${C_idx[$prev_key]}" "${N_idx[$curr_key]}" "${CA_idx[$curr_key]}" "${C_idx[$curr_key]}"
                    echo "#"
                fi
            fi

            # Calculate PSI Angle
            if [[ -n "${N_idx[$curr_key]}" && -n "${CA_idx[$curr_key]}" && -n "${C_idx[$curr_key]}" && -n "${N_idx[$next_key]}" ]]; then
                echo "#  $label PSI"
                if [ "$first_restraint_written" -eq 0 ]; then
                    printf " &rst iat=%s,%s,%s,%s, \n" "${N_idx[$curr_key]}" "${CA_idx[$curr_key]}" "${C_idx[$curr_key]}" "${N_idx[$next_key]}"
                    printf "   %s  &end\n" "$RESTRAINT_PARAMS"
                    echo "#"
                    first_restraint_written=1
                else
                    printf " &rst iat=%s,%s,%s,%s, &end\n" "${N_idx[$curr_key]}" "${CA_idx[$curr_key]}" "${C_idx[$curr_key]}" "${N_idx[$next_key]}"
                    echo "#"
                fi
            fi

        done
    done
} > "$OUT_FILE"

# Append other restraints if the file was provided and exists
if [ -n "$OTHER_RESTRAINTS_FILE" ]; then
    cat "$OTHER_RESTRAINTS_FILE" >> "$OUT_FILE"
fi

echo "Restraints written to '$OUT_FILE'."

