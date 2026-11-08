# School and Teacher Data: Stata Coding Sample

A Stata workflow developed for the **INSPIRE Internship Program** coding exercise. The analysis checks school and teacher survey responses against the supplied codebook, applies documented corrections, links survey records to village-level administrative data, and summarizes teacher characteristics by school ownership.

The main script, [`CODING SAMPLE - RUN.do`](<CODING SAMPLE - RUN.do>), follows Questions 1–14 of the exercise and includes an illustrative school-level randomization extension.

## Repository contents

| File or directory | Purpose |
| --- | --- |
| `CODING SAMPLE - RUN.do` | Main cleaning, merging, validation, and analysis script. |
| `School data.csv` | Original school survey: 200 schools. |
| `Teacher data.csv` | Original teacher survey: 601 records, including one empty duplicate. |
| `Admin Data.xlsx` | Village-level administrative information. |
| `Codebook dataset.xlsx` | Variable definitions and permitted response codes. |
| `Stata Task - INSPIRE Internship Program A.pdf` | Original exercise instructions. |
| `raw_data/` | Copies of the five supplied input files, refreshed from the repository root on each run. |
| `clean_data/` | Generated Stata datasets, including intermediate and final merged data. |
| `outputs/` | Analysis log and exported summary statistics. |

## Requirements and execution

Use **Stata 17 or later**. The script uses built-in commands; no additional Stata packages are required. Keep all five supplied input files in the repository root.

In Stata, set the working directory to your local checkout and run:

```stata
cd "/path/to/repository"
do "CODING SAMPLE - RUN.do"
```

Alternatively, pass the repository path as the script's first argument:

```stata
do "/path/to/repository/CODING SAMPLE - RUN.do" "/path/to/repository"
```

The script creates `raw_data/`, `clean_data/`, and `outputs/` if needed. Rerunning it replaces the copied inputs and generated outputs while leaving the original files in the repository root intact. The script header refers to `INSPIRE_solution.do`; use the actual filename shown above.

## Workflow

1. **Check and clean school responses.** Review categorical codes, other-track text, and interviewer comments. Correct ownership for school `106203`, clear inconsistent other-track text for schools `106109` and `108210`, and correct ownership and track for school `108209`. Remove school `107204` after withdrawal of consent.
2. **Merge administrative data.** Join schools to villages using `villageid`, verify that all records match, recode village setting, construct region identifiers, convert interview timestamps, and group Maths, Science, and IT Technology into a scientific track category.
3. **Check and clean teacher responses.** Review identifiers, categorical codes, ages, and birth dates. Remove the empty duplicate for school `108210`, teacher `1`, and check that each school lists one Head Teacher, one Deputy Head Teacher, and one Senior Teacher.
4. **Build the teacher-level analysis data.** Exclude teachers from the school that withdrew consent, merge school and village information using `schoolid`, and check grade–subject consistency.
5. **Produce descriptive statistics.** Report teacher age and gender by public/private ownership, including sample size, mean, range, standard deviation, minimum, maximum, and the 5th and 90th percentiles.
6. **Illustrate random assignment.** Use seed `20261010` to assign 99 of the 199 retained schools to treatment and 100 to control, then compare baseline characteristics. The implemented allocation is across all retained schools, without village stratification. These results appear in Stata and the log; the simulated assignment is not saved as a separate dataset.

## Generated outputs

| File | Contents |
| --- | --- |
| `clean_data/school_clean_before_merge.dta` | Cleaned school survey before the administrative merge. |
| `clean_data/admin_school_merged.dta` | School and administrative data before subsequent recoding. |
| `clean_data/admin_school_clean.dta` | Cleaned school and village data: 199 schools. |
| `clean_data/teacher_clean.dta` | Teacher survey after duplicate removal: 600 teachers, before consent-based exclusion. |
| `clean_data/teacher_school_admin_clean.dta` | Merged analysis data: 597 teachers from 199 schools. |
| `outputs/teacher_summary_by_ownership.csv` | Age and gender summary statistics by school ownership. |
| `outputs/INSPIRE_analysis.log` | Command output, validation checks, tables, and randomization summaries. |

The merged teacher dataset is saved before the grade–subject flag and ownership value labels are added. Those later changes are available during execution but are not written back to that dataset. Teacher-listing protocol checks are also reported during execution rather than saved in `teacher_clean.dta`.

## Findings and interpretation

- After duplicate removal, 198 of 200 schools meet the teacher-listing role protocol. Schools `104204` and `110205` have inconsistent role compositions; their reported roles are retained.
- One retained teacher, teacher `1` at school `101105`, reports Maths in Grade 1, contrary to the exercise's grade–subject rule. The script flags the response and retains the reported values for clarification.
- The exported ownership summary includes 420 teachers in public schools and 174 in private schools. Three teachers have unknown school ownership and are excluded from these comparisons.
- Gender is coded `1 = Male`, `2 = Female`; its mean minus one gives the proportion female among nonmissing responses.

The exercise narrative references Tanzania and the regions Kilimanjaro and Dodoma, while the supplied administrative data use **Lobaye** and **Ouaka**. The script preserves the region names in the data and documents the discrepancy.

The randomization extension is a simulation for trial planning. These baseline data and the simulated assignment do not establish treatment effects.

The checked-in analysis log includes unrelated commands appended after the exercise output. Rerun the script to replace it with a log from the current workflow.
