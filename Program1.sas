libname dm_1985 "C:\Users\hkpu\Documents\dm\1985-2003";

data cdata;
set dm_1985.funda_1985;
run;

data temp; set cdata;
if not missing(sich);
proc sort; by gvkey datadate;
proc sort nodupkey; by gvkey;
data sic; set temp;
rename sich = sic;
data sic; set sic;
keep gvkey sic;
run;
proc sort data = sic; by gvkey;
proc sort data = cdata; by gvkey;
data cdata1; merge cdata sic; by gvkey; 
run;
/* We use historical SIC; if it is missing, we use the first-year SIC extracted above.*/
/* For example observations: 209-219*/
data cdata1; set cdata1;
if sich =. then sich = sic;
drop sic;
run;
/*Construct sic2 and CIK2*/
data cdata2; set cdata1;
sic4=sich;
sic2=int(sich/100);
CIK2 = input(CIK,10.);
/*Warning1: This is from the orginal table. The adjust seem makes sense but no instructions to do*/
if fyr > 0 and fyr <= 5 then cyear=fyear+1;
else if fyr >= 6 then cyear=fyear;
if fyr > 0 then fyrend= intnx('monthly',mdy(fyr,1,cyear),0,'end');
if not missing(fyrend) then fyrbegin = intnx('monthly',fyrend,-11,'begin');
format fyrend fyrbegin date9.;
run;*207002;*213288;