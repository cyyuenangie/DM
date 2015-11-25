

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
if fyear>1988 and fyear<2003;
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
************** Start from here ****************************;
***********************************************************;
data temp(drop=gvkey1); set cdata1;
gvkey1 = lag(gvkey);
ibcom1ag = lag(ibcom);
if gvkey ne gvkey1 then do;
ibcom1ag=.;
end;
run;

 
data temp2(drop=gvkey1 gvkey2 gvkey3);                                          
merge temp                                          
      temp(firstobs=2 keep=gvkey ibcom                 
               rename=(gvkey=gvkey1 ibcom=ibcom1))          
      temp(firstobs=3 keep=gvkey ibcom                 
               rename=(gvkey=gvkey2 ibcom=ibcom2))      
 	   temp(firstobs=4 keep=gvkey ibcom                 
               rename=(gvkey=gvkey3 ibcom=ibcom3)) ; 
if gvkey ne gvkey1 then do; ibcom3=.; ibcom2=.; ibcom1=.; end;                            
if gvkey ne gvkey2 then do;ibcom2=.; ibcom3=.;end;  
if gvkey ne gvkey3 then do;ibcom3=.;end;
if  ibcom3 ne . and ibcom2 ne . and ibcom1 ne . then do; ibcom_sum_3=ibcom3+ibcom2+ibcom1; end;
run; 
 

 
data temp3(drop=gvkey1 gvkey2 gvkey3);                                          
merge temp2                                          
      temp2(firstobs=2 keep=gvkey oancf                 
               rename=(gvkey=gvkey1 oancf=oancf1))          
      temp2(firstobs=3 keep=gvkey oancf                 
               rename=(gvkey=gvkey2 oancf=oancf2))      
 	   temp2(firstobs=4 keep=gvkey oancf                 
               rename=(gvkey=gvkey3 oancf=oancf3)) ; 
if gvkey ne gvkey1 then do; oancf3=.; oancf2=.; oancf1=.; end;                            
if gvkey ne gvkey2 then do;oancf2=.; oancf3=.;end;  
if gvkey ne gvkey3 then do;oancf3=.;end;
if  oancf3 ne . and oancf2 ne . and oancf1 ne . then do; oancf_sum_3=oancf3+oancf2+oancf1; end;
run; 






