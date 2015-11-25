
libname DM 'C:\Users\Ahn\Desktop\DM';
rsubmit;
******************* Merge with Compustat ******************;
options errors=1 noovp;
options nocenter ps=max ls=78;
options mprint source nodate symbolgen macrogen;
options msglevel=i;

%let begindate='01jan1990'd; * start calendar date of fiscal period end;
%let enddate='31DEC2010'd; * end calendar date of fiscal period end 2009;

%let comp_where= &begindate<=datadate<=&enddate and 
				 (consol='C') and (popsrc='D') and (indfmt='INDL') and 
				 (datafmt='STD') and (curcd='USD');
%let comp_list= gvkey datadate cik fyr fyear sich
CSHO PRCC_F IB OANCF AT EPSPX PPEGT ACT LCT RE OIADP SALE
NOPI XINT INTC OIBDP CHE LT CAPX DLC DLTT SEQ CSHR 
MIB TXDB RECCH INVCH CEQ APALCH TXACH AOLOCH DVPSX_F 
XRD XAD FCA FINCF INVT RECT COGS PPENT PRCC_C; 

data cc1; set comp.funda;
where &comp_where;
keep &comp_list;
proc sort data=cc1 nodupkey; by gvkey datadate;
proc download data=cc1 out=DM.funda; run;

data t1; set comp.FUNDA_FNCD;
if year(datadate) ge 1980;
keep gvkey datadate sale_fn;
proc download data=t1 out=DM.FNCD;
run;

data t2; set comp.WRDS_SEGMERGED;
if year(datadate) ge 1980;
keep gvkey datadate sid;
proc download data=t2 out=DM.SEGMERGED;
run;


**** Compute 2 sic codes using sich ****;
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

data cdata1; set cdata1;
if sich =. then sich = sic;
drop sic;
run;

data cdata2; set cdata1;
sic4=sich;
sic2=int(sich/100);
CIK2 = input(CIK,10.);

if fyr > 0 and fyr <= 5 then cyear=fyear+1;
else if fyr >= 6 then cyear=fyear;
if fyr > 0 then fyrend= intnx('monthly',mdy(fyr,1,cyear),0,'end');
if not missing(fyrend) then fyrbegin = intnx('monthly',fyrend,-11,'begin');
format fyrend fyrbegin date9.;
run;*207002;

************** Start from here ****************************;
data cdata1; set DM.funda;
year = year(datadate);
year1 = lag(year);
year2 = lag2(year);
year3 = lag3(year);
year4 = lag4(year);

gvkey1 = lag(gvkey);
gvkey2 = lag2(gvkey);
gvkey3 = lag3(gvkey);
gvkey4 = lag4(gvkey);

at1 = lag(at);
invt1 = lag(invt);
rect1 = lag(rect);
if gvkey ne gvkey1 or year ne year1+1 then do;
at1=.;invt1=.;rect1=.;
end;
run;

data cdata2; set cdata1;
avg_at = (at+at1)/2;
ROA = IB/avg_at;
ROA1 = ROA;
ROA2 = lag(ROA);
ROA3 = lag2(ROA);
ROA4 = lag3(ROA);
ROA5 = lag4(ROA);
if gvkey ne gvkey1 or year ne year1+1 then do;
	ROA2=.; end;
if gvkey ne gvkey2 or year ne year2+2 then do;
	ROA3=.; end;
if gvkey ne gvkey3 or year ne year3+3 then do;
	ROA4=.; end;
if gvkey ne gvkey4 or year ne year4+4 then do;
	ROA5=.; end;
EARNVOL = STD(of ROA1-ROA4);

drop ROA1 ROA2 ROA3 ROA4 ROA5 year1 year2 year3 year4
gvkey1 gvkey2 gvkey3 gvkey4;
run;

data cdata2; set cdata2;
opcycle = (((invt+invt1)/2)/(cogs/365))+(((rect+rect1)/2)/(sale/365));
run;

proc sort data=cdata2 nodupkey; by gvkey datadate;
run;

** Industry adjusted ROA and Operating cycle **;
proc sort data=cdata2; by year sic2;

proc means data=cdata2 noprint;
by year sic2;
var roa opcycle;
output out=industry 
mean=mean_roa mean_cycle;
run;

proc sql;
 create table cdata3 as 
 select a.*, (a.roa - b.mean_roa) as ABNROA, 
			 (a.opcycle - b.mean_cycle) as ABNOPCYCLE
   from cdata2 as a left join industry as b 
     on a.year=b.year
	and a.sic2=b.sic2;	
 quit;


 ** Four firm concentration ratio **;
data s1; set cdata3;
if missing(sale)=0;
keep year sic2 sale;
run;
proc sort data=s1; by year sic2;
proc sql; create table s2 as select distinct
	year, sic2, sale, sum(sale) as total_sale
	from s1 group by year, sic2
	order by year, sic2;
	quit;
	
data s2; set s2;
share = sale/total_sale;
if missing(share)=0;
run;

proc sort data=s2; by year sic2 descending share;
run;

data s2; set s2; by year sic2 descending share;
if first.sic2=1 then td_count=0;
td_count=td_count+1;
retain td_count;
run;

data s3; set s2;
if td_count le 4;
run;

proc sql; create table s4 as select distinct
	year, sic2, share, sum(share) as CR
	from s3 group by year, sic2
	order by year, sic2;
	quit;

data s5; set s4; by year sic2;
if first.sic2;
keep year sic2 CR;
run;

proc sql;
 create table cdata4 as 
 select a.*, b.CR 
   from cdata3 as a left join s5 as b 
     on a.year=b.year
	and a.sic2=b.sic2; 
    quit;

proc sort data=cdata4 nodupkey; by gvkey datadate;
run;

** M&A **;
data merger; set DM.FNCD;
if sale_fn="AA";
MA=1;
keep gvkey datadate MA;
run;

proc sort data=merger; by gvkey datadate;
proc sql;
 create table m1 as 
 select a.*, b.MA 
   from cdata4 as a left join merger as b 
     on a.gvkey=b.gvkey
	and a.datadate=b.datadate; 
    quit;

proc sort data=m1; by gvkey datadate;
data m1; set m1;
year1=lag(year);
year2=lag2(year);
gvkey1=lag(gvkey);
gvkey2=lag2(gvkey);
MA1 = lag(MA);
MA2 = lag2(MA);
if gvkey ne gvkey1 or year ne year1+1 then do;	MA1=.; end;
if gvkey ne gvkey2 or year ne year2+2 then do;	MA2=.; end;

if MA = 1 or MA1 = 1 or MA2 = 1 then MNA=1; else MNA=0;

drop year1 year2 gvkey1 gvkey2;
run;

proc sql;
 create table cdata5 as 
 select a.*, b.MNA
   from cdata4 as a left join m1 as b 
     on a.gvkey=b.gvkey
	and a.datadate=b.datadate; 
    quit;
proc sort data=cdata5 nodupkey; by gvkey datadate;
run;


** Number of Segments **;
data seg; set DM.SEGMERGED;
if ~missing(gvkey) and ~missing(datadate) and ~missing(sid);
keep gvkey datadate sid;
run;

proc sort data=seg nodupkey; by gvkey datadate sid;
run;

data seg1; set seg; by gvkey datadate sid;
if first.datadate=1 then td_count=0;
td_count=td_count+1;
retain td_count;
run;

data seg2; set seg1; by gvkey datadate sid;
if last.datadate;
run;

proc sql;
 create table cdata6 as 
 select a.*, log(b.td_count) as LOGSEG 
   from cdata5 as a left join seg2 as b 
     on a.gvkey=b.gvkey
	and a.datadate=b.datadate;	
    quit;


**  Capital Issue financing **;
proc sort data=cdata6; by gvkey descending datadate;
run;
data h1; set cdata6; by gvkey descending datadate;
year1 = lag(year);
year2 = lag2(year);
gvkey1 = lag(gvkey);
gvkey2 = lag2(gvkey);
fincf1 = lag(fincf);
fincf2 = lag2(fincf);
if gvkey ne gvkey1 or year ne year1-1 then do;	fincf1=.; end;
if gvkey ne gvkey2 or year ne year2-2 then do;	fincf2=.; end;
if fincf=. then fincf=0;
if fincf1=. then fincf1=0;
if fincf2=. then fincf2=0;

sum_fincf = fincf+fincf1+fincf2;
extfin = sum_fincf/avg_at;
run;

proc sort data=h1; by gvkey datadate;
run;

proc sql;
 create table cdata7 as 
 select a.*, b.extfin 
   from cdata6 as a left join h1 as b 
     on a.gvkey=b.gvkey
	and a.datadate=b.datadate;	
    quit;

proc sort data=cdata7 nodupkey; by gvkey datadate;
run;

** Other variables **;
data cdata8; set cdata7;
CONOWN = 1-(CSHR/CSHO);
CONOWN2 = 1-(CSHR/(CSHO*1000));

*MVE = CSHO*PRCC_F;									* Calculates the market value of equity;
*(LNMVE = log(MVE);									* LOG takes the natural log;

BTM = CEQ / MVE;							* Calculates the book-to-market ratio;
LNBTM1 = log(BTM);
LNBTM2 = LOG((AT-LT)/MVE);						

ACC = (IB-OANCF)/(AT-LT);
SIZE_TA = log(AT);
LEV = DLTT/AT;
LEV2 = (DLC+DLTT)/AT;
if FCA ne . then foreign=1; else foreign=0;

/*Cash_Holdings = CHE / AT;
DTB	= (CSHO*DVPSX_F)/(AT-LT);							* Dividend;
CapitalEx = CAPX/AT;
ROA2 = ib / at;										* Calculates return on assets;
ROE = IB/(AT-LT);	
SIZE_Sale = log(SALE);
PM = (SALE - COGS)/SALE;   *Gross profit margin;
RD = XRD/SALE;
AD = XAD/SALE;
if XRD=. then RD=0;	else RD=RD;
if XAD=. then AD=0;	else AD=AD;*/

keep gvkey datadate permno cik fyr fyear sic sic4 sic2
EBIT_COV EBITDA_COV FREECASH LEVERAGE DEBT_EBITDA ROC FFO 
ROA ABNROA EARNVOL OPCYCLE ABNOPCYCLE
MNA LOGSEG EXTFIN CR CONOWN CONOWN2 FOREIGN
CASH_HOLDINGS DTB CapitalEX 
AT SALE MVE LNMVE BTM LNBTM1 LNBTM2 ROA2 ROE ACC 
SIZE_SALE SIZE_TA PM LEV LEV2 RD AD
MTB MB beta idio tangibility currentratio sleverage prcc_f accruals2
ACCRUALS CapIntensity Zscore Earn_Volatility Choice;
run;







































