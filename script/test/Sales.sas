LIBNAME saslib base 'E:\project\tools\SAS\data';

DATA saslib.sales;
	infile datalines dsd missover;
	input Emp_ID Dept Sales Date;
	format Sales COMMA10. Date yymmdd10.;
	informat Sales dollar10. Date date9.;
	label Emp_ID = "员工ID" Dept = "部门" Sales = "销售数据" Date = "销售时间";
datalines;
ET001, TSG, $10000, 01JAN2012
ED002,    , $12000, 01FEB2012
ET004, TSG, $5000, 02MAR2012
EC002, CSG, $23000, 01APR2012
ED004, QSG,       , 01AUG2012 
;
RUN;

PROC CONTENTS data = saslib.sales;
RUN;


PROC PRINT data = saslib.sales;
RUN;

PROC PRINT data = saslib.sales noobs label;
RUN;