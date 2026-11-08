/*

CONTEXT
This script was developed for an INSPIRE internship Stata exercise using
school, teacher and village-level administrative data supplied with the task.

PURPOSE
The code checks responses against the supplied codebook, corrects documented
entry errors, merges datasets, checks teacher-listing and teaching protocols,
and produces descriptive statistics by school ownership.

HOW TO RUN
Set Stata's working directory to the folder containing the five supplied files, 
then run: do INSPIRE_solution.do. The script preserves the originals and saves 
files in raw_data/, clean_data/ and outputs/, replacing generated files on reruns.

*/

version 17.0
clear all
set more off
set varabbrev off
args project_dir
if `"`project_dir'"' == "" local project_dir `"`c(pwd)'"'
cd `"`project_dir'"'
foreach dir in raw_data clean_data outputs {
    capture mkdir "`dir'"
}
capture log close _all
log using "outputs/INSPIRE_analysis.log", text replace

* Keep a self-contained copy of the supplied materials for reproducibility.
foreach f in "School data.csv" "Teacher data.csv" "Admin Data.xlsx" "Codebook dataset.xlsx" "Stata Task - INSPIRE Internship Program A.pdf" {
    confirm file "`f'"
    copy "`f'" "raw_data/`f'", replace
}

/* QUESTION 1: . RCT explanation

An RCT randomly allocates eligible units to treatment and control groups, every 
school has a strictly positive and strictly lower than one probability of getting 
assigned to the treatment.

Here, every schools reports results from a survey carried out in Tanzania. Thus, 
collecting baseline data for a future RCT experiment. For the 
experiment to be well-set the researcher should consider that the schools should 
be comparable in terms of students. One technique that coud be implemented is 
stratified randomization, where treatment is allocated to 50% of the school 
sample and schools are selected based on being located to similar 
neighbourhoods in terms of comparability.
 
Given the setting it is also important to consider ethical constents, and required 
power before launching the experiment. 

*/

* QUESTION 2. ******************************************************************

import delimited using "raw_data/School data.csv", ///
    clear varnames(1) encoding("UTF-8")
 
* Report values outside the permitted codes, including missing responses.
* Consent: 1 = Yes; 2 = No.
count if !inlist(consent, 1, 2)
list schoolid consent if !inlist(consent, 1, 2), noobs

* Ownership: 1 = Public; 2 = Private; -99 = Don't know.
count if !inlist(own, 1, 2, -99)
list schoolid own if !inlist(own, 1, 2, -99), noobs

* Main track: 1-9; -96 = Other; -99 = Don't know.
count if !inlist(main_sub, 1, 2, 3, 4, 5, 6, 7, 8, 9, -96, -99)
list schoolid main_sub if ///
    !inlist(main_sub, 1, 2, 3, 4, 5, 6, 7, 8, 9, -96, -99), noobs

* Other-track text should appear only when Other (-96) is selected.
list schoolid main_sub main_sub_other if ///
    (main_sub != -96 & strtrim(main_sub_other) != "") | ///
    (main_sub == -96 & strtrim(main_sub_other) == ""), noobs

* Review comments that may require corrections.
list schoolid consent own main_sub interviewer_comment if ///
    !inlist(lower(strtrim(interviewer_comment)), ///
    "", "ok", "nothing", "all good", "respondent was collaborative"), noobs
	
/*COMMENT: 
The dataset contains 200 uniquely identified schools, with complete IDs and valid, positive integer school counts.
All observed categorical codes are permitted, but school 106203 has missing ownership; its comment identifies it as public. Schools 106109 and 108210 contain other-track text although Other was not selected. Comments also identify school 108209 as private with a Maths track and confirm school 107204 withdrew consent.*/


* QUESTION 3: ******************************************************************

* School 106203: ownership is missing, but the comment says public.
list schoolid own interviewer_comment if schoolid == 106203
replace own = 1 if schoolid == 106203

* Schools 106109 and 108210: clear other-track text because Other was not selected.
replace main_sub_other = "" if inlist(schoolid, 106109, 108210)

* School 108209: recorded as public with a Religious Studies track.
* The comment says private with a Maths track: correct both values.
list schoolid own main_sub interviewer_comment if schoolid == 108209
replace own = 2 if schoolid == 108209
replace main_sub = 1 if schoolid == 108209

* School 107204: the head teacher withdrew consent.
list schoolid consent interviewer_comment if schoolid == 107204
drop if schoolid == 107204


* Comments have been incorporated into the corrections.
drop interviewer_comment

* Save the cleaned school dataset before the Q4 merge.
save "clean_data/school_clean_before_merge.dta", replace

* QUESTION 4  ******************************************************************
import excel using "raw_data/Admin Data.xlsx", ///
    firstrow case(lower) clear

* The Excel header "long" is imported as f because long is reserved.
rename f longitude

* Confirm villageid is numeric and uniquely identifies each village.
confirm numeric variable villageid
isid villageid

* Remember the administrative column order.
ds
local admin_vars `r(varlist)'
tempfile admin
save `admin'

* Load the cleaned school dataset.
use "clean_data/school_clean_before_merge.dta", clear
confirm numeric variable villageid

* Remember school columns, excluding the shared villageid.
ds villageid, not
local school_vars `r(varlist)'

* Merge multiple schools to one administrative record per village.
merge m:1 villageid using `admin'
tabulate _merge
assert _merge == 3
drop _merge

* Administrative columns first, followed by school columns.
* villageid appears once, among the administrative columns.
order `admin_vars' `school_vars'

save "clean_data/admin_school_merged.dta", replace

* QUESTION 5 *******************************************************************

* Replace text categories with their codebook codes.
replace type = "1" if upper(strtrim(type)) == "URBAN"
replace type = "2" if upper(strtrim(type)) == "RURAL"
replace type = "3" if upper(strtrim(type)) == "MIXED"

* Convert the column from string to numeric.
destring type, replace

* Apply the variable description and value labels.
label variable type "Type of village"
label define type_lbl 1 "URBAN" 2 "RURAL" 3 "MIXED", replace
label values type type_lbl

assert inlist(type, 1, 2, 3)

* QUESTION 6********************************************************************

* Q6 has an unresolved source inconsistency: the actual regions are Lobaye
* and Ouaka, not Kilimanjaro and Dodoma.
* assign 1 = Lobaye and 2 = Ouaka instead of the names in the instructions.
gen byte regionid = .
replace regionid = 1 if lower(strtrim(region)) == "lobaye"
replace regionid = 2 if lower(strtrim(region)) == "ouaka"

label variable regionid "Region identifier"
label define region_lbl 1 "Lobaye" 2 "Ouaka", replace
label values regionid region_lbl

assert !missing(regionid)
order regionid, after(region)

* QUESTION 7 *******************************************************************

gen double timebegun_dt = clock(strtrim(timebegun), "MDYhm")

* Display, for example: 18oct2024 10:18.
format timebegun_dt %tcDDmonCCYY_HH:MM

* Verify that all nonempty timestamps converted successfully.
assert !missing(timebegun_dt) if strtrim(timebegun) != ""

* Replace the original column, preserving its position and name.
order timebegun_dt, before(timebegun)
drop timebegun
rename timebegun_dt timebegun
label variable timebegun "Interview start date and time"

* QUESTION 8 *******************************************************************

* Group Maths (1), Science (2) and IT Technology (3) into category 100.
* Keep main_sub unchanged.
clonevar track_group = main_sub
replace track_group = 100 if inlist(main_sub, 1, 2, 3)

label variable track_group "School track with scientific aggregate"
label define track_group_lbl ///
    -99 "Don't know" -96 "Other" ///
    4 "French (Literature)" 5 "Humanities (Art and Culture)" ///
    6 "English (Literature)" 7 "Professional tracks" ///
    8 "Religious Studies" 9 "Economics/Social track" ///
    100 "SCIENTIFIC AGGREGATE", replace
label values track_group track_group_lbl

* Row percentages show the track shares within each village setting.
* Exclude unknown or missing tracks from the denominator.
tabulate type track_group if !missing(track_group) & track_group != -99, row

/* COMMENT: 
The share of schools with a scientific track is 33.00% in urban settings,
36.71% in rural settings and 35.00% in mixed settings.
Scientific tracks include Maths, Science and IT Technology.
*/

* QUESTION 9********************************************************************
save "clean_data/admin_school_clean.dta", replace

* QUESTION 10 ******************************************************************

import delimited using "raw_data/Teacher data.csv", ///
    clear varnames(1) encoding("UTF-8")

* Check missing identifiers and duplicate school-teacher combinations.
list schoolid teacherid if missing(schoolid, teacherid), noobs

duplicates tag schoolid teacherid, generate(duplicate_id)
list if duplicate_id > 0, noobs

* Gender: 1 = Male; 2 = Female.
list schoolid teacherid gender if !inlist(gender, 1, 2), noobs

* Position is supplied as text rather than the codebook's numeric codes.
* Check the corresponding permitted descriptions.
list schoolid teacherid position if ///
    !inlist(upper(strtrim(position)), ///
    "HEAD TEACHER", "DEPUTY HEAD TEACHER", "SENIOR TEACHER", ///
    "OTHER", "OTHER (SPECIFY)"), noobs

* Subject: codes 1-8, 11-13, or -96 = Other.
list schoolid teacherid sub_teach if ///
    !inlist(sub_teach, 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, -96), noobs

* Grade: integers from 1 to 6.
list schoolid teacherid grade_teach if ///
    !inlist(grade_teach, 1, 2, 3, 4, 5, 6), noobs

* Age should be reported in whole years.
* Ages outside 18-100 are flagged for review, not automatically corrected:
* this is a plausibility threshold, not a codebook restriction.
list schoolid teacherid age if ///
    missing(age) | age != floor(age) | !inrange(age, 18, 100), noobs

* Check birth-date components and whether they form a valid calendar date.
gen double dob = mdy(u6_mnth, u6_day, u6_year)
format dob %tdDDmonCCYY
label variable dob "Date of birth"

list schoolid teacherid u6_day u6_mnth u6_year if ///
    missing(dob) | u6_day != floor(u6_day) | ///
    u6_mnth != floor(u6_mnth) | u6_year != floor(u6_year), noobs

* CORRECTION: school 108210, teacher 1 appears twice.
* One row contains the teacher's details; the other has an entirely empty
* response section. Remove only that empty duplicate, keeping the complete row.
drop if schoolid == 108210 & teacherid == 1 & duplicate_id > 0 ///
    & strtrim(name) == "" & strtrim(position) == "" ///
    & missing(gender) & missing(age) ///
    & missing(u6_day) & missing(u6_mnth) & missing(u6_year) ///
    & missing(sub_teach) & missing(grade_teach)

drop duplicate_id

* Verify that each school-teacher combination is now unique.
isid schoolid teacherid

* Save the cleaned teacher dataset.
save "clean_data/teacher_clean.dta", replace

/* COMMENT:
The raw teacher dataset contains 601 records. One is an empty duplicate
for school 108210, teacher 1; removing it leaves 600 records.
The remaining categorical responses match the codebook's permitted values.
Role composition within schools and grade-subject consistency are checked
in the following exercises.
*/

* QUESWTION 11 *****************************************************************

*Each school should list three teachers: one Head Teacher, one Deputy Head Teacher and one Senior Teacher.

bysort schoolid: gen n_respondents = _N
bysort schoolid: egen n_head = ///
    total(upper(strtrim(position)) == "HEAD TEACHER")
bysort schoolid: egen n_deputy = ///
    total(upper(strtrim(position)) == "DEPUTY HEAD TEACHER")
bysort schoolid: egen n_senior = ///
    total(upper(strtrim(position)) == "SENIOR TEACHER")

gen byte protocol_ok = n_respondents == 3 & ///
    n_head == 1 & n_deputy == 1 & n_senior == 1

* Report results once per school.
egen school_tag = tag(schoolid)
tabulate protocol_ok if school_tag

list schoolid n_respondents n_head n_deputy n_senior ///
    if school_tag & !protocol_ok, noobs

/* COMMENT:
After removing the empty duplicate, all 200 schools have three respondents,
but two schools do not follow the required role composition.
School 104204 has two Head Teachers and no Deputy Head Teacher.
School 110205 has two Senior Teachers and no Head Teacher.
Thus, 198 of 200 schools (99%) comply with the listing protocol.
Retain the reported roles: there is insufficient information to correct them.
*/

* QUESTION 12 ******************************************************************

use "clean_data/teacher_clean.dta", clear

* Exclude teachers from the school that withdrew consent.
drop if schoolid == 107204

* Merge school and village information onto each teacher.
merge m:1 schoolid using "clean_data/admin_school_clean.dta"

* Check that all observations matched.
tabulate _merge
assert _merge == 3
drop _merge

* Verify the teacher-level identifiers and save the merged dataset.
isid schoolid teacherid
save "clean_data/teacher_school_admin_clean.dta", replace

* QUESTION 13 ******************************************************************

*Grades 1-2 should only teach Counting (11), Reading (12) or Writing (13).
gen byte subject_inconsistent = ///
    inlist(grade_teach, 1, 2) & !inlist(sub_teach, 11, 12, 13) ///
    if !missing(grade_teach, sub_teach)

* Count and display violations.
count if subject_inconsistent == 1
list schoolid teacherid grade_teach sub_teach ///
    if subject_inconsistent == 1, noobs

/* COMMENT:
One inconsistency is identified: teacher 1 in school 101105 reports
teaching Maths (subject code 1) in Grade 1, where only Counting, Reading
and Writing are permitted. Retain the reported values and flag the record
for clarification, since we cannot determine whether subject or grade is wrong.
*/

* QUESTION 14 ******************************************************************

*Summary statistics by school ownership: 1 = Public, 2 = Private.
label define own_lbl 1 "Public" 2 "Private", replace
label values own own_lbl

* Print the requested table; exclude unknown or missing ownership.
tabstat age gender if inlist(own, 1, 2), by(own) ///
    statistics(n mean range sd min max p5 p90) columns(statistics)

* Export the same statistics to CSV.
preserve

tempfile summary
tempname results
postfile `results' str7 school_type str6 variable long n ///
    double mean range sd minimum maximum p5 p90 using `summary', replace

foreach g in 1 2 {
    local school_type "Public"
    if `g' == 2 local school_type "Private"

    foreach v in age gender {
        quietly summarize `v' if own == `g', detail
        post `results' ("`school_type'") ("`v'") ///
            (r(N)) (r(mean)) (r(max)-r(min)) (r(sd)) ///
            (r(min)) (r(max)) (r(p5)) (r(p90))
    }
}

postclose `results'
use `summary', clear
export delimited using "outputs/teacher_summary_by_ownership.csv", replace

restore

/* COMMENT:
Statistics are calculated separately for teachers in public and private schools.
Range equals maximum minus minimum. Gender is coded 1 = Male, 2 = Female:
its mean minus 1 equals the proportion female among nonmissing responses.
The remaining gender statistics describe category codes, not a continuous trait.
*/

/* OPTIONAL EXTENSION: Planning a school-randomized trial

These are baseline data: treatment effects cannot be estimated.
This section:
1. Generates an illustrative allocation within villages.
2. Provides balance checks conditional on receiving REAL assignment data.

The proposed allocation is not the assignment used in the original trial.
*/

/* OPTIONAL ANALYSIS: Simulated school-level randomization
Randomly allocate approximately half the schools to treatment, then examine
baseline balance. This is a proposed allocation, not the actual RCT assignment.
*/

preserve
use "clean_data/admin_school_clean.dta", clear
isid schoolid

* 1. Randomly allocate schools to treatment.
* Sort before setting the seed so the allocation is reproducible.
sort schoolid
set seed 20261010

gen double random_number = runiform()
sort random_number schoolid

* With 199 schools, assign 99 to treatment and 100 to control.
gen byte treatment = _n <= floor(_N/2)
label define treatment_lbl 0 "Control" 1 "Treatment", replace
label values treatment treatment_lbl
tabulate treatment

* 2. Prepare baseline characteristics for balance checks.
* Treat unknown ownership as missing rather than as Public.
gen byte private_school = own == 2 if inlist(own, 1, 2)

* Category indicators allow comparisons of proportions across groups.
gen byte urban = type == 1 if !missing(type)
gen byte rural = type == 2 if !missing(type)
gen byte mixed = type == 3 if !missing(type)

* Use the actual region names supplied in the data.
gen byte ouaka = lower(strtrim(region)) == "ouaka" ///
    if strtrim(region) != ""

* Define the characteristics before examining balance.
local characteristics totstuds tot_classrooms tot_teach ///
    private_school urban rural mixed ouaka

* Print means, standard deviations and nonmissing sample sizes.
* Means of binary indicators represent proportions.
tabstat `characteristics', by(treatment) ///
    statistics(n mean sd) columns(statistics)
	
local characteristics totstuds tot_classrooms tot_teach ///
    private_school urban rural mixed ouaka
	
/* COMMENT:
The simulated randomization assigns 99 schools to treatment and 100 to control.
Average enrolment, classroom counts, teacher counts and regional composition
are similar across groups. However, treatment schools are more often private
(33.67% versus 25.00%) and less often urban (45.45% versus 55.00%).
One treated school has unknown ownership and is excluded from that comparison.

These descriptive differences reflect possible chance imbalances, not evidence
that randomization failed. Stratifying by ownership or location could improve
balance on these characteristics in a future design.
*/

