

```sas
/*********************************
建模代码
郁晴
20180404
***********************************************/
options mlogic mprint;
OPTION VALIDVARNAME=ANY;
option compress = yes;
libname cp "E:\AnalystPersonal\model";
/*数据清洗过程：1.缺失值特殊编码转为缺失值；2.计算缺失度；3.计算单一程度；4.计算离散特征的属性值个数*/
data cp.jyd;
	set cp.m_lf_;
   /*将人行-1、-99改为缺失值*/
	array num_var _numeric_;
    do over num_var;
		if num_var in (-99,-1)  then num_var = .;
	end;
run; 
/*计算缺失度*/
data cp.queshi;
	set cp.jyd1;
	array arr1{*} _NUMERIC_ ;
	array arr2{*} _CHARACTER_ ;
    length variable $50;
    do i = 1 to dim(arr1);
    	if missing(arr1(i)) then do;
        	variable =vname(arr1(i));  /*数值型缺失*/
            output;
         end;
      end;
      do j = 1 to dim(arr2);
      	if missing(arr2(j)) then do;
         	variable = vname(arr2(j)); /*字符型缺失*/
            output;
         end;
      end;
     keep variable;
run;
proc sql noprint;

      select count(*) into : N from cp.jyd1;

      create table cp.miss as
      select variable label = "缺失变量名",count(*) as frequency label = "缺失频数",
      input(compress(put(calculated frequency / &N.,percent10.2),'%'),best32.) as percent label = %nrstr("%缺失占比")
      from cp.queshi
      group by variable
	  having percent >70;

	  select variable into : miss_list separated by ' ' from cp.miss;
quit;
data cp.jyd2;
	set cp.jyd1;
	drop &miss_list.;
run;
/*计算单一程度*/
%macro var_namelist(data=,coltype=,tarvar=,dsor=,);
%let lib=%upcase(%scan(&data.,1,'.'));  
%let dname=%upcase(%scan(&data.,2,'.'));  
%global var_list var_num;   
proc sql ;
	create table &dsor. as
	select name
	from sashelp.VCOLUMN       
	where left(libname)="&lib." and
	left(memname)="&dname." and
	type="&coltype." and lowcase(name)^=lowcase("&tarvar.") ;  
quit;
%mend;
%macro freq(data=,coltype =);
%var_namelist(data=&data.,coltype=&coltype.,tarvar = default,dsor=tmp);
proc sql noprint;
	select count(*) into : n from  tmp ;
	select name into:char_name1-:char_name%left(&n.) from tmp 
;
quit;
%put &char_name1;
data aa_&coltype.;
	length  name $200. count 8 percent 8;
	if _n_ = 1 then delete;
run;
%do i = 1 %to &n.;
proc freq data = &data. noprint;
	table  &&char_name&i./missing out= a;
run;
proc sql ;
	create table a1 as 
	select "&&char_name&i." as name, max(percent)as percent,max(count) as count
	from a ;
quit;
proc append base =aa_&coltype.  force data = a1;
run;
%end;
proc datasets lib = work nolist;
	delete  a a1;
quit;
%mend;
/*去掉取值较多的离散特征:这里取离散特征小于20的特征*/
%macro meta_char(data = ,coltype =,outdata = );
/*设置一个空数据集*/
data  &outdata.;
	length  name $100. num_ 8 percent 8;
	format percent percent8.2;
	if _n_ = 1 then delete;
run;
%var_namelist(data=&data.,coltype=&coltype.,tarvar = default,dsor=tmp);
proc sql noprint;
	select count(*) into : n from  tmp ;
	select name into:char_name1-:char_name%left(&n.) from tmp 
;
quit;
%do i = 1 %to &n.;
	proc freq data = &data. noprint;
		table &&char_name&i. / missing out = a;
	run;
	proc sql noprint;
		select count(*) into : total from &data.;
		select count(*) into : t_var from  a;
	quit;
	%put &total. &t_var;
	proc sql ;
		create table  a1 as select distinct "&&char_name&i." as  name ,
        &t_var. as  num_ , &t_var./&total. as percent format = percent8.2
	    from  a;
	quit;
	proc append base =&outdata.  force data = a1; run;
%end;
proc datasets lib = work nolist;
	delete  a a1;
quit;
%mend;
/*样本抽样过程：1.跨期抽样；2.时间内抽样*/
/*跨期验证数据集*/
data cp.valid_jyd cp.develop;
	set cp.jyd4;
	if  submit_month >= mdy(2,1,2017) then output cp.valid_jyd;
	else output cp.develop;
run;
/*2:8分训练测试集*/
proc sort data=cp.develop ;
	by default submit_month;
run;
proc surveyselect data=cp.develop rate=0.8  seed = 20180322 method=srs out=cp.train_jy(drop = SelectionProb SamplingWeight) noprint;
  strata default submit_month;
run;
proc sql ;
	create table cp.test_jy as
	select * from cp.develop
	where pieces_no_id not in (select pieces_no_id from cp.train_jy)
	;
quit;
/*降维过程：1.计算IV；2.stepwise过程*/
/*直接计算离散特征的iv*/
%var_namelist(data=cp.train_jy,coltype=char,tarvar = default,dsor=cp.tmp_char);
%macro char_iv(lib=,data = ,col=,outdata = );
proc datasets lib=&lib. nodetails noprint;
	delete  &outdata.;
run;
%var_namelist(data=&data.,coltype=&col.,tarvar = default,dsor=tmp);
proc sql noprint;
	select sum(case when default=1 then 1 else 0 end), sum(case when default=0 then 1 else 0 end), count(*) into :tot_bad, :tot_good, :tot_both
	from  &data.;
	select count(*),name into :char_num,:char_list separated by ' ' from tmp
     where name not in ("pieces_no_id");
quit;
data &lib..&outdata.;
	length varname $50. tier $50. tot_num  num_rate huai_rate woe pre_iv group 8.;
	format num_rate huai_rate percent8.2;
	if _n_ = 1 then delete;
run;
%do i=1 %to &char_num.;   
	%let  char_name_&i.= %scan(&char_list.,&i.);
		%put &char_name_1.;
	proc sql;
		create table total  as 
		(select  
		"&&char_name_&i." as varname,
		 &&char_name_&i. as tier,
		count(*) as tot_num,
		count(*)/&tot_both as num_rate,
		sum(case when default=1 then 1 else 0 end) as bad_num,
		sum(case when default=1 then 1 else 0 end)/&tot_bad as bad_rate,
		log((sum(case when default=1 then 1 else 0 end)/&tot_bad)/(sum(case when default=0 then 1 else 0 end)/&tot_good)) as woe,
		((sum(case when default=1 then 1 else 0 end)/&tot_bad)-(sum(case when default=0 then 1 else 0 end)/&tot_good))
		*log((sum(case when default=1 then 1 else 0 end)/&tot_bad)/(sum(case when default=0 then 1 else 0 end)/&tot_good)) as pre_iv,
		sum(case when default=1 then 1 else 0 end)/count(*) as huai_rate
		from &data.
		group by "&&char_name_&i.",tier
		)
		order by  &&char_name_&i.;
	quit;
	data t_&i.;
		length varname $100.;
		set total;
		group=_n_;
	run; 
	proc append base=&lib..&outdata. data=t_&i. force;run;
	proc datasets lib=work nodetails noprint;
	delete total n_: d_: _namedat;
quit;
%end;
proc datasets lib = work nodetails noprint;
	delete t_:;
run;
%mend ;
%char_iv(lib = cp,data = cp.train_jy,col= char,outdata = total_char);
/*计算连续特征的iv
1.先等账户数分成20箱
2.针对20箱进行计算iv
*/
proc contents data = cp.train_jy1 noprint out = cp.train_var(keep = name type label);run;
proc sql noprint;
	select name into : num_var separated by  ' ' from cp.train_var
	where name not in ("submit_time1","submit_month");
quit;
%put &num_var.;
%macro rank(name=,lib=,dsout=,data=);
%if %sysfunc(exist(&lib.. &dsout.)) ne 0 %then %do;
proc datasets lib = &lib.  nolist;
	delete &dsout.;
quit;
%end;
%let i = 1;
	%do %until(%scan(&name.,&i.,' ')=);
	%let namei=%scan(&name.,&i.,' ');
	%if &i.=1 %then %do;
			proc rank data = &data.  out =  &dsout.  groups = 20 ties=low;
				var &namei.;
				ranks R&namei.;
			run;
			data  &dsout.;
				set  &dsout.;
				if missing(R&namei.) then R&namei. = -9999;
			run; 
	 %end;
	 %else %do;
			proc rank data = &data.  out =  rank&i (keep = &namei. R&namei.)  groups = 20 ties=low; 
				var &namei.;
				ranks R&namei.;
			run;
			data  rank&i.;
				set  rank&i.;
				if missing(R&namei.) then R&namei. = -9999;
			run; 
			data  &dsout.;
				merge  &dsout.   rank&i.;
			run;
			proc datasets lib=work  nolist;
			   delete  rank&i./memtype=data;
			quit;
		%end;
%let i=%eval(&i.+1);
%end;
%mend;
/*对分成20箱的连续特征进行单变量分析*/
%macro restart_woe(data=,lib = ,dsout=);
%if %sysfunc(exist(&lib..&dsout.)) ne 0 %then %do;
	proc datasets lib = &lib. nolist;
	delete &dsout.;
	quit;
%end;
%var_namelist(data=&data.,coltype=num,tarvar=default,dsor=tmp)
proc sql noprint;
	select sum(case when default=1 then 1 else 0 end), sum(case when default=0 then 1 else 0 end), count(*) into :tot_bad, :tot_good, :tot_both
	from &data.;
	select count(*) into : n from  tmp  where substr(name,1,1) = "R";
	select name into : name1-:name%left(&n.) from tmp where substr(name,1,1) = "R"
	;
quit;
%put &name1.;
%put &n.;
%do i = 1 %to &n.;
data _null_;
call symput("norname&i.",substr("&&name&i.",2,length("&&name&i.")-1));
run;
%put norname1;
proc sql;
	create table work.woe&i. as 
	(select  &i. as id,
	"&&name&i." as varname,
	&&name&i. as tier,
	max(&&norname&i.) as max_bin,
	min(&&norname&i.) as min_bin,
	count(*) as cnt,
	input(compress(put(count(*)/ &tot_both.,percent10.2),'%'),best32.) as cnt_pct label = %nrstr("%账户数占比"),
	count(*)/&tot_both as cnt_pct label = "账户数",
	sum(case when default=0 then 1 else 0 end) as sum_good label ="好客户数",
	input(compress(put(calculated sum_good / &tot_good.,percent10.2),'%'),best32.) as dist_good label = %nrstr("%好客户占比"),
	sum(case when default=1 then 1 else 0 end) as sum_bad label = "坏客户数",
	input(compress(put(calculated sum_bad / &tot_bad.,percent10.2),'%'),best32.) as dist_bad label = %nrstr("%坏客户占比"),
	log((sum(case when default=1 then 1 else 0 end)/&tot_bad)/(sum(case when default=0 then 1 else 0 end)/&tot_good)) as woe,
	((sum(case when default=1 then 1 else 0 end)/&tot_bad)-(sum(case when default=0 then 1 else 0 end)/&tot_good))
	*log((sum(case when default=1 then 1 else 0 end)/&tot_bad)/(sum(case when default=0 then 1 else 0 end)/&tot_good)) as pre_iv,
	input(compress(put(sum(case when default=1 then 1 else 0 end)/count(*) ,percent10.2),'%'),best32.) as bad_rate label = %nrstr("%坏账率")
	from &data.
	group by "&&name&i.",tier
	)
	order by  &&name&i.;
quit;
%if  &i. = 1 %then %do;
data &dsout.;
length  varname $50. ;
set work.woe&i;
run;
%end;
%else %do;
data  &dsout.;
	length  varname $50.;
	set  &dsout.  woe&i;
run;
%end;
%end;
%mend;
%restart_woe(data =cp.train_jy3,lib = cp,dsout =cp.num_iv );
/*计算iv*/
proc sql;
	create table cp.num_iv1 as select  *,
	sum(pre_iv) as iv
	from cp.num_iv
	group by varname
	;
quit;
proc sort data = cp.num_iv1 nodupkey;
	by descending varname;
run;
proc sql noprint;
	create table cp.tmp_r as 
	select count(*),varname into : iv_num,: iv_name separated by  ' ' from cp.num_iv1
	where iv>=0.02;
quit;
data cp.tmp_r;
	set cp.tmp_r;
	varname1 = substr(varname,2,length(varname)-1);
run;
proc sql noprint;
	select varname1 into : iv_name1 separated by ' ' from cp.tmp_r;
	select varname  into : riv_name separated by ' ' from cp.tmp_r;
	select varname into : iv_char separated by ' ' from cp.iv_char 
	where iv>=0.02;
quit;
%put &iv_name1. &riv_name. &iv_char.;
data cp.train_jy4;
	retain default pieces_no_id submit_time1 submit_month &iv_char.;
	set cp.train_jy3;
	keep default  pieces_no_id  submit_time1 submit_month  &iv_name1. &iv_char. &riv_name.;
run;
/*转换woe*/
%macro CalcWOE(DsIn, IVVar, DVVar, WOEDS, WOEVar, DSout);

PROC FREQ data =&DsIn noprint;
  tables &IVVar * &DVVar/out=Temp_Freqs;
run;

proc sort data=Temp_Freqs;
 by &IVVar &DVVar;
run;

Data Temp_WOE1;
 set Temp_Freqs;
 retain C1 C0 C1T 0 C0T 0;
 by &IVVar &DVVar;
 if first.&IVVar then do;
      C0=Count;
	  C0T=C0T+C0;
	  end;
 if last.&IVVar then do;
       C1=Count;
	   C1T=C1T+C1;
	   end;
 if last.&IVVar then output;
 drop Count PERCENT &DVVar;
call symput ("C0T", C0T);
call symput ("C1T", C1T);
run;

Data &WOEDs;
 set Temp_WOE1;
  GoodDist=C0/&C0T;
  BadDist=C1/&C1T;
  if(GoodDist>0 and BadDist>0) Then   WOE=log(BadDist/GoodDist);
  Else WOE=.;
  keep &IVVar WOE;
run;

proc sort data=&WOEDs;
 by WOE;
 run;
proc sql noprint;
	create table &dsout as 
	select a.* , b.woe as &WOEvar from &dsin a, &woeds b where a.&IvVar=b.&IvVar; 
quit;

%mend;
%let woe_name = &iv_char. &riv_name.;
%put &woe_name.;
%macro woe();
%let i = 1;
%do %until (%scan(&woe_name.,&i.,' ')= );
	%let name2i = %scan(&woe_name.,&i,' ');
		%CalcWOE(cp.train_jy4, &name2i.,default, woe_&i., W&name2i., cp.train_jy4)
%let i = %eval(&i.+1);
%end;
%mend;
%woe();
proc contents data = cp.train_jy4 noprint out = cp.train_var(keep = name label type);run;
/*多变量分析 vif*/
proc sql noprint;
	create table cp.log_name as 
	select name from cp.train_var
	where substr(name,1,1) = "W" 
;			
quit;
proc sql noprint;
	select name into : woe_var separated by ' ' from cp.train_var
	where substr(name,1,1) = "W";
quit;
%put &woe_var.;
ods listing close;
ods results off;
ods output
parameterestimates=cp.vif_result;
proc reg data=cp.train_jy4;
	model default=&woe_var./vif;
run;
ods results on;
ods listing;
data cp.Vif_result;
	set cp.Vif_result;
	Variable=upcase(Variable);
run;
data cp.log_name;
	set cp.log_name;
	name = lowcase(name);
run;
proc sql;
	create table cp.log_drop as select * from cp.log_name
	where name not in (select Variable from cp.Vif_result where VarianceInflation>4);
quit;
proc sql noprint;
	select distinct name into : log_name1 separated by  ' ' from  cp.log_drop;
quit;
/*显著性检验使用逐步筛选法*/
Proc Logistic data=cp.train_jy4 out=cp.train_stat; 
Model default (Event='1') = &log_name1. / selection=stepwise 
sle=0.05 sls=0.05;
output out =cp.model_pred p = phat ;
run;
proc npar1way data=cp.model_pred noprint ;
	class default;
	var phat;
	output out=cp.model_ks(keep=_d_ p_ksa rename=(_d_=KS p_ksa=P_value));
run; 
data cp.train_stat1;
	set cp.train_stat;
	keep _numeric_;
	drop _lnlike_;
run;
proc transpose data=cp.train_stat1 out=cp.train_stat2 (where=(COL1^=.));
run;
/*整理数据集,找出stepwise的单变量*/
data cp.num_iv_r;
retain name;
	set cp.num_iv;
	name = strip(tranwrd(varname,"R",""));
run;
proc sql ;
	create table cp.woe_map_num as select * from cp.num_iv_r
	where  name  in (select strip(tranwrd(_name_,"WR","")) from cp.train_stat2);
	create table cp.woe_map_char as select * from cp.total_char
	where  varname in(select strip(tranwrd(_name_,"W","")) from cp.train_stat2);
quit;
/*导入单变量分析后的变量*/
data cp.map_num1;
	set cp.map_num;
	length qujian $20.;
	min1=put(min_bin,8.);
	max1=put(max_bin,8.);
	if min_bin=max_bin and min_bin ^=. then qujian=strip(min1);
	else if min_bin = . and max_bin = . then qujian = strip("null");
	else qujian=strip("["||strip(min1)||","||strip(max1)||"]");
	drop min1 max1;
	t=_n_;
run;
proc sort data =cp.map_num1;
	by name;
run;
data cp.map_num2;
	set cp.map_num1;
	by name;
	retain hb;
	if first.name then hb = 1;
	else hb = hb+1;
run;
/*把连续特征手调分组映射到数据集上*/
%macro group1();
proc sql noprint;
	select max(t) into:c from cp.map_num2;
quit;
%put &c.;
%do i=1 %to &c.;
	data null;
		set cp.map_num2;
		if t=&i.;
		call symputx("name",name);
		call symputx("min",min_bin);
		call symputx("max",max_bin);
		call symputx("hb",hb);
	run;
	data  cp.train_jy4;
		set cp.train_jy4;
		if &name.>=&min. and &name.<=&max. then G&name.=&hb.;
	run;
%end;
%mend;
%group1();
/*因为离散特征变量较少，所以手动分组*/
/*计算手调分组后的iv及坏账率*/

%macro IV(data=,coltype= );
%var_namelist(data=&data.,coltype=&coltype.,tarvar=default,dsor=tmp);
proc sql noprint;
select sum(case when default=1 then 1 else 0 end), sum(case when default=0 then 1 else 0 end), count(*) into :tot_bad, :tot_good, :tot_both
from &data.;
proc sql noprint;
select count(*) into : n from  tmp where substr(name,1,1) = "G";
select name into : x1-:x%left(&n.) from tmp where substr(name,1,1) = "G"
;
quit;
%put &n.;
/*循环计算每个变量的WOE和IV*/
%do i=1 %to &n.;
/*计算WOE*/
proc sql;
	create table woe&i as
	(select "&&x&i" as variable,
	&&x&i as tier,
    count(*) as cnt,
    input(compress(put(count(*)/ &tot_both.,percent10.2),'%'),best32.) as cnt_pct label = %nrstr("%账户数占比"),
	count(*)/&tot_both as cnt_pct label = "账户数",
	sum(case when default=0 then 1 else 0 end) as sum_good label ="好客户数",
	input(compress(put(calculated sum_good / &tot_good.,percent10.2),'%'),best32.) as dist_good label = %nrstr("%好客户占比"),
	sum(case when default=1 then 1 else 0 end) as sum_bad label = "坏客户数",
	input(compress(put(calculated sum_bad / &tot_bad.,percent10.2),'%'),best32.) as dist_bad label = %nrstr("%坏客户占比"),
	log((sum(case when default=1 then 1 else 0 end)/&tot_bad)/(sum(case when default=0 then 1 else 0 end)/&tot_good)) as woe,
	((sum(case when default=1 then 1 else 0 end)/&tot_bad)-(sum(case when default=0 then 1 else 0 end)/&tot_good))
	*log((sum(case when default=1 then 1 else 0 end)/&tot_bad)/(sum(case when default=0 then 1 else 0 end)/&tot_good)) as pre_iv,
	input(compress(put(sum(case when default=1 then 1 else 0 end)/count(*) ,percent10.2),'%'),best32.) as bad_rate label = %nrstr("%坏账率")
	from &data.
group by &&x&i
)
order by &&x&i;
quit;
/*计算IV*/
proc sql;
create table iv&i as select "&&x&i" as variable,
sum(pre_iv) as iv
from woe&i; 
quit;
%end;

/*合并IV结果*/
/*data iv_&coltype.;*/
/*length variable $100.;*/
/*set iv1-iv&n.;*/
/*run;*/
/*根据IV值排序*/
/*proc sort data=iv_&coltype.;*/
/*by decending iv;*/
/*quit;*/
%mend;
%iv(data = cp.train_jy5,coltype = num);
data cp.map_num_iv;
set iv1-iv26;
run;
data cp.map_num_woe;
set woe1 - woe26;
run;
proc datasets lib = work  nolist;
	delete iv: woe: _:;
quit;
proc sort data = cp.map_num_iv; by iv;run;
/*全部大于0.02 计算woe 纳入模型*/
proc sql noprint;
	select variable  into : name_all separated by ' ' from cp.map_num_iv
 	where iv >=0.02;
quit;
%put &name_all.;
%let name_allf = &name_all. Beducation Guse1 Ghangye education;
%macro woe();
%let i = 1;
%do %until (%scan(&name_allf.,&i.,' ')= );
	%let name_alli = %scan(&name_allf.,&i,' ');
		%CalcWOE(cp.train_jy5, &name_alli.,default, woe_&i., W_&name_alli., cp.train_jy5)
%let i = %eval(&i.+1);
%end;
%mend;
%woe();
%var_namelist(data=cp.train_jy5,coltype=num,tarvar=default,dsor=cp.woe_var);
proc sql noprint;
	create table cp.log_name as 
	select name from cp.woe_var
	where substr(name,1,2) = "W_" 
	;
quit;
proc sql noprint;
	select distinct name into : log_name separated by  ' ' from cp.log_name;
quit;
ods listing close;
ods results off;
ods output
parameterestimates=cp.vif_result;
proc reg data=cp.train_jy5;
	model default=&log_name./vif;
run;
ods results on;
ods listing;
data cp.vif_result;
	set cp.Vif_result;
	Variable=upcase(Variable);
run;

/*筛选VIF小于5的变量*/
data cp.vif_result;
	set cp.vif_result;
	variable = lowcase(variable);
run;
data cp.log_name;
	set cp.log_name;
	name = lowcase(name);
run;
proc sql;
	create table cp.log_drop as select * from cp.log_name
	where name not in (select Variable from cp.Vif_result where VarianceInflation>5);
quit;
proc sql noprint;
	select distinct name into : log_name1 separated by  ' ' from  cp.log_drop;
quit;
%put &log_name1.;
ods output parameterestimates=cp.parameter;
proc logistic data=cp.train_jy5 outest= cp.model_params desc;
model default (event='1')= &log_name1.
 /rsq stb 
selection =stepwise  sls=0.01 sle=0.01 ;
output out =cp.model_pred p = phat ;
run;
proc npar1way data=cp.model_pred noprint ;
	class default;
	var phat;
	output out=cp.model_ks(keep=_d_ p_ksa rename=(_d_=KS p_ksa=P_value));
run; 
data cp.model;
	set cp.model_pred;
	cs=log(phat/(1-phat));
    score=MIN(MAX(300-ROUND(cs/Log(2)*50,1),0),1000);
run;
/*整理输出数据集*/
data cp.parameter_good;
	length variable1 $50.;
	retain variable1;
	set cp.parameter;
	if variable = "W_Gir_id_is_reabnorm" then variable1 = "W_Gir_id_is_reabnormal";
	else if variable = "W_Gbr_m12_mobile_not" then variable1 = "W_Gbr_m12_mobile_notbank_allnum";
	else if variable = "W_Gir_m12_cell_x_id_" then variable1 = "W_Gir_m12_cell_x_id_cnt";
	else if variable = "W_Gtd_largConFinQry_" then variable1 = "W_Gtd_largConFinQry_6m";
	else variable1 = variable;
	drop variable;
run;
data cp.map_num_woe1;
	set cp.map_num_woe;
	varname = strip("W_"||variable);
	name = substr(variable,2,length(variable)-1);
run;
proc sql;
	create table cp.test_woe_rule as select * from cp.map_num_woe1
	where  varname in (select variable1 from cp.parameter_good) ;
quit;
proc sql ;
	create table cp.test_woe_rule1a as select 
	a.*,b.min_bin,max_bin,qujian,hb 
	from cp.test_woe_rule a left join cp.map_num2 b
	on a.name = b.name and a.tier = b.hb;
quit; 
/*将woe map到时间内测试集上*/
%macro test_woe(data);

data cp.test_woe_rule1b;
	set cp.test_woe_rule1a;
	a=_n_;
run;

proc sql noprint;
	select max(a) into:c from cp.test_woe_rule1b;
quit;
%do i=1 %to &c.;
	data null;
		set cp.test_woe_rule1b;
		if a=&i.;
		call symputx("name",name);
		call symputx("min",min_bin);
		call symputx("max",max_bin);
		call symputx("woe",woe);
	run;
	data &data.;
		set &data.;
		if &name.>=&min. and &name. < = &max. then w_&name=&woe.;
	run;
%end;
%mend;
%test_woe(cp.test_jy);
/*手填行业的woe*/
%test_woe(cp.valid_jyd);
/*对模型系数进行转置*/
data cp.parameter_good1;
	set cp.parameter_good;
	if substr(variable1,3,1) = "G" then variable2 = compress(variable1,"G");
	else variable2 = variable1 ;
run;
proc transpose data=cp.Parameter_good1 out=cp.par_zh prefix=p_;
	id Variable2;
	var Estimate;
run;
/*将每个变量的回归系数添加到测试集中*/
proc sql;
	create table cp.test_jy2 as select a.*,b.*
	from cp.test_jy1 a
	left join cp.par_zh b
	on 1=1;
quit;
%macro pro_js();
	proc sql noprint;
		select count(distinct Variable2) into:count from cp.Parameter_good1;
	quit;
	%put &count.;
	%do i=1 %to &count;
		data _null_;
		set cp.Parameter_good1;
		if _n_=&i;
		call symputx("var",Variable2);
		run;
		%put &var.;
		data cp.test_jy2;
		set cp.test_jy2;
		z_&var.=&var.*p_&var.;
		run;
	%end;
%mend;
%pro_js();
data cp.test_jy3;
	set cp.test_jy2(drop = z_intercept intercept);
	a_sum=sum(of z_:);
run;
proc sql noprint;
	select Estimate into:Intercept from cp.Parameter_good1 where Variable2="Intercept";
quit;
%put &intercept.;
data cp.test_jy4;
	set cp.test_jy3;
	odds=a_sum+&Intercept.;
	e_odds=exp(odds);
	phat=e_odds/(1+e_odds);
run;
proc npar1way data=cp.test_jy4 noprint ;
	class default;
	var phat;
	output out=cp.test_jy_ks(keep=_d_ p_ksa rename=(_d_=KS p_ksa=P_value));
run; 

/*转换分数*/
data cp.test_jy5;
	set cp.test_jy4;
	cs=log(phat/(1-phat));
	score=MIN(MAX(300-ROUND(cs/Log(2)*50,1),0),1000);	
run;
/*计算gini*/
proc freq data=cp.test_jy5 noprint ;
tables phat*default;
test smdrc;
output out=cp.gini_test_jy(keep=_SMDRC_ ) smdrc;
run;
/******************跨期验证数据集同理*******************/
```










