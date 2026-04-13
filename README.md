# AMBER Dihedral Restraints Generator

A lightweight, fast Bash utility designed to automate the generation of PHI and PSI backbone dihedral angle restraints for AMBER molecular dynamics simulations.

## Features
Automated PDB Parsing: Extracts N, CA, and C backbone atom indices directly from the input PDB file.
AMBER-Ready Output: Automatically formats the specific four-atom connections for PHI and PSI restraints into standard AMBER `&rst` syntax.
Flexible Chain Handling: Robustly processes PDB files whether they include specific chain identifiers or are missing chain data altogether.
Restraint Consolidation: Includes a built-in flag to easily append external restraint files to the generated backbone restraints.

## Prerequisites
A UNIX-like environment (Linux, macOS, or WSL)
`bash` (Standard Bash environment)

## Usage
```bash
./makedihedral_rst.sh -i <protein.pdb> -r <1,2,3,4,5> -o <output.dat> [-c <A,B>] [-e <other_restraints.dat>]
```

### Arguments
| Flag | Description | Required |
|---|---|---|
| `-i` | Input PDB file containing the protein structure. | Yes |
| `-r` | Comma-separated list of target residue numbers (e.g., `10,11,12`). | Yes |
| `-o` | Output file where the generated restraints will be saved. | Yes |
| `-c` | Target chain(s) to apply restraints to (e.g., `A,B`). If omitted, applies based on residue numbers regardless of chain. | No |
| `-e` | Path to an external restraints file. Its contents will be appended to the output file. | No |

## Example
Generate restraints for residues 25 through 28 on chain A, and combine them with existing distance restraints:

```bash
./makedihedral_rst.sh -i complex.pdb -r 25,26,27,28 -c A -o all_restraints.dat -e distance_rst.dat
```

