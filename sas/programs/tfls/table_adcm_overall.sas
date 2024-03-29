**** input treatment code data as adam adsl data.;
data adsl;
    length usubjid $ 3;
    label usubjid = "Unique Subject Identifier"
            trtpn = "Planned Treatment (N)";
    input usubjid $ trtpn @@;
    datalines;
101 1  102 0  103 0  104 1  105 0  106 0  107 1  108 1  109 0  110 1
111 0  112 0  113 0  114 1  115 0  116 1  117 0  118 1  119 1  120 1
121 1  122 0  123 1  124 0  125 1  126 1  127 0  128 1  129 1  130 1
131 1  132 0  133 1  134 0  135 1  136 1  137 0  138 1  139 1  140 1
141 1  142 0  143 1  144 0  145 1  146 1  147 0  148 1  149 1  150 1
151 1  152 0  153 1  154 0  155 1  156 1  157 0  158 1  159 1  160 1
161 1  162 0  163 1  164 0  165 1  166 1  167 0  168 1  169 1  170 1
;
run;

**** input sample concomitant medication data as sdtm cm domain.;
data cm;
    label usubjid = "Unique Subject Identifier"
          cmdecod = "Standardized Medication Name";
    input usubjid $ 1-3 cmdecod $ 5-27;
    datalines;
101 ACETYLSALICYLIC ACID
101 HYDROCORTISONE
102 VICODIN
102 POTASSIUM
102 IBUPROFEN
103 MAGNESIUM SULFATE
103 RINGER-LACTATE SOLUTION
115 LORAZEPAM
115 SODIUM BICARBONATE
116 POTASSIUM
117 MULTIVITAMIN
117 IBUPROFEN
119 IRON
130 FOLIC ACID
131 GABAPENTIN
132 DIPHENHYDRAMINE
135 SALMETEROL
140 HEPARIN
140 HEPARIN
140 NICOTINE
141 HYDROCORTISONE
141 IBUPROFEN
;

**** perform a simple count of each treatment arm and output result;

**** as macro variables.  n1 = 1st column n for active therapy,
**** n2 = 2nd column n for placebo, n3 represents the 3rd column total n.;
proc sql noprint;
    **** place the number of active subjects in &n1.;
    select count(distinct usubjid) format = 3.
        into :n1
            from adsl
                where trtpn = 1;

    **** place the number of placebo subjects in &n2.;
    select count(distinct usubjid) format = 3.
        into :n2
            from adsl
                where trtpn = 0;

    **** place the total number of subjects in &n3.;
    select count(distinct usubjid) format = 3.
        into :n3
            from adsl
                where trtpn ne .;
quit;

***** merge cconcomitant medications and treatment data.
***** keep records for subjects who had conmeds and took study therapy.
***** get unique concomitant medications within patients.;
proc sql
    noprint;
    create table cmtosum as
        select unique(c.cmdecod) as cmdecod, c.usubjid, t.trtpn
            from cm as c, adsl as t
                where c.usubjid = t.usubjid
                    order by usubjid, cmdecod;
quit;

**** get medication counts by treatment and place in dataset counts.;
**** turn off lst output.;
ods listing close;

**** send sums by treatment to counts data set.;
ods output crosstabfreqs = counts;

proc freq
    data = cmtosum;
    tables trtpn * cmdecod;
run;

ods output close;
ods listing;

proc sort
    data = counts;
    by cmdecod;
run;

**** merge counts data set with itself to put the three
**** treatment columns side by side for each conmed.  create group
**** variable which are used to create break line in the report.
**** define col1-col3 which are the count/% formatted columns.;
data cm;
    merge counts(where = (trtpn = 1) rename = (frequency = count1))
        counts(where = (trtpn = 0) rename = (frequency = count2))
        counts(where = (trtpn = .) rename = (frequency = count3))
        end = eof;
    by cmdecod;
    keep cmdecod rowlabel col1-col3 section;
    length rowlabel $ 25 col1-col3 $ 10;

    **** label "any medication" row and put in first group.
    **** by medication counts go in the second group.;
    if cmdecod = '' then
        do;
            rowlabel = "ANY MEDICATION";
            section = 1;
        end;
    else
        do;
            rowlabel = cmdecod;
            section = 2;
        end;

    **** CALCULATE PERCENTAGES AND CREATE N/% TEXT IN COL1-COL3.;
    pct1 = (count1 / &n1) * 100;
    pct2 = (count2 / &n2) * 100;
    pct3 = (count3 / &n3) * 100;
    col1 = put(count1,3.) || " (" || put(pct1, 3.) || "%)";
    col2 = put(count2,3.) || " (" || put(pct2, 3.) || "%)";
    col3 = put(count3,3.) || " (" || put(pct3, 3.) || "%)";
run;

**** USE PROC REPORT TO WRITE THE CONMED TABLE TO FILE.;
options nodate nonumber missing = ' ';
ods escapechar='#';
* ods pdf style=htmlblue file='program5.5.pdf';

proc report
    data=cm
    nowindows
    split = "|";
    columns section rowlabel col1 col2 col3;
    define section  /order order = internal noprint;
    define rowlabel /order width=25 "Preferred Medication Term";
    define col1     /display center width=14 "Active|N=&n1";
    define col2     /display center width=14 "Placebo|N=&n2";
    define col3     /display center width=14 "Total|N=&n3";

    compute after section;
        line '#{newline}';
    endcomp;

    title1 j=l 'Company/Trial Name'
           j=r 'Page #{thispage} of #{lastpage}';
    title2 j=c 'Table 5.5';
    title3 j=c 'Summary of Concomitant Medication';
run;

ods pdf close;