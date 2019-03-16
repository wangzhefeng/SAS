/* 第三章 对单个数据集的处理
* 3.1 选取部分变量
*/


/* KEEP=选项*/
DATA work.shoes_part1;
	set sashelp.shoes (keep = Product Stores Sales);
RUN;
PROC PRINT data = work.shoes_part1 (obs = 10) noobs;
RUN;

/* DROP=选项*/
DATA work.shoes_part2;
	set sashelp.shoes (drop = Region Subsidiary Inventory Returns);
RUN;
PROC PRINT data = work.shoes_part2 (obs = 10) noobs;
RUN;

/* KEEP语句*/
DATA work.shoes_part3;
	set sashelp.shoes;
	keep Product Stores Sales;
RUN;
PROC PRINT data = work.shoes_part3 (obs = 10) noobs;
RUN;

/* DROP语句*/
DATA work.shoes_part4;
	set sashelp.shoes;
	drop Region Subsidiary Inventory Returns; 
RUN;
PROC PRINT data = work.shoes_part4 (obs = 10) noobs;
RUN;

/*一个DATA步中创建多个数据集*/
DATA work.shoes_sales (keep = Product Stores Sales)
	 work.shoes_inventory (drop = Product Stores Sales);
	set sashelp.shoes;
RUN;
PROC PRINT data = work.shoes_sales (obs = 5) noobs;
	title "Product Salses";
RUN;
PROC PRINT data = work.shoes_inventory (obs = 5) noobs;
	title "Product Inventory";
RUN;

/* 有效使用数据集中的KEEP=,DROP=选项*/
DATA work.shoes_sales (keep = Product Stores Sales)
     work.shoes_inventory (keep = Product Inventory Returns);
	set sashelp.shoes (drop = Region Subsidiary);
RUN;
PROC PRINT data = work.shoes_sales (obs = 5) noobs;
	title "Product Sales";
RUN;
PROC PRINT data = work.shoes_inventory (obs = 5) noobs;
	title "Product Inventory";
RUN;



/* 3.2 操作数据集的观测值*/

/* IF THEN DELETE*/
DATA work.shoes_enough1;
	set sashelp.shoes;
	if Stores <= 20 then delete;
RUN;
PROC PRINT data = work.shoes_enough1 noobs;
	title "Shoes Enough 1";
RUN;


/* IF */
DATA work.shoes_enough2;
	set sashelp.shoes;
	if Stores > 20;
RUN;
PROC PRINT data = work.shoes_enough2 noobs;
	title "Shoes Enough 2";
RUN;


/* OUTPUT */
DATA work.shoes_enough
	work.shoes_short;
	set sashelp.shoes;
	if Stores > 20 then output work.shoes_enough;
	else output work.shoes_short; 
RUN;
PROC PRINT data = work.shoes_enough noobs;
	title "Shoes Enough";
RUN;
PROC PRINT data = work.shoes_short noobs;
	title "Shoes Short";
RUN;


/* IF THEN ELSE*/
DATA work.Inventory1;
	set sashelp.shoes;
	if Region = 'Africa' then 
		Stores = Stores * 2;
RUN;
PROC PRINT data = work.Inventory1 (obs = 5) noobs;
	title 'INVENTORY';
RUN;


/* DO END*/
DATA work.Inventory2;
	set sashelp.shoes;
	if Region = 'Africa' then 
		do;
			Stores = Stores * 1.2;
			Sales = Sales * 2;
		end;
	else
		do;
			Stores = Stores * 1.3;
			Sales = Sales * 3;
		end;
RUN;
PROC PRINT data = work.Inventory2 (obs = 5) noobs;
	title 'Inventory 2';
RUN;


/* IF THEN ELSE IF THEN ELSE*/


/* SELECT WHEN OTHERWISE END*/
DATA work.Inventory3;
	set sashelp.shoes;
	select (Region);
		when ('Africa') Stores = Stores * 1.2;
		when ('South America') Stores = Stores * 1.3;
		otherwise Stores = Stores * 1.4;
	end;
RUN;
PROC PRINT data = work.Inventory3 (obs = 5) noobs;
	title 'Inventory 3';
RUN;

/* ************************************************************* 
 * 分组 排序                                                  
 * ************************************************************* */
/* SORT out BY*/
PROC SORT data = sashelp.shoes output = work.shoes_sorted;
	by Subsidiary Stores;
RUN;


/* SORT out BY descending*/
PROC SORT data = sashelp.shoes out = work.shoes_sorted_desc;
	by Subsidiary descending Stores;
RUN;


/* FIRST.BY LAST.BY */
DATA work.shoes_first_last;
	set sashelp.shoes;
	by Subsidiary;
	if first.Subsidiary or last.Subsidiary;
RUN;

PROC PRINT data = work.shoes_first_last noobs;
RUN;



/* NODUPKEY */
PROC IMPORT out = sasuser.contact2_raw
	datafile = "E:\project\tools\SAS\data\contact2.csv"
	dbms = csv replace;
	getnames = yes;
	datarow = 2;
RUN;

PROC PRINT data = sasuser.contact2_raw noobs;
	title 'All Observations';
RUN;

PROC SORT data = sasuser.contact2_raw
	out = sasuser.contact2
	dupout = work.contact2_dup
	nodupkey;
	by Name;
RUN;

PROC PRINT data = sasuser.contact2 noobs;
	title 'Observations with Duplicate By Values Deleted';
RUN;

PROC PRINT data = work.contact2_dup nobos;
	title 'Duplicate Observations';
RUN;



/**************************************************************
 * 3.3 创建新变量 
 ***************************************************************/


/* RENAME= RENAME */

DATA work.shoes_1_rn;
	set sashelp.shoes (rename = (Region = RegionName));
	First_Name = scan(RegionName, 1);
	Last_Name = scan(RegionName, 2);
RUN;

DATA work.shoes_2_rn (rename = (Region = RegionName));
	set sashelp.shoes;
	First_Name = scan(Region, 1);
	Last_Name = scan(Region, 2);
RUN;


DATA work.shoes_3_rn;
	set sashelp.shoes;
	rename Region = RegionName;
	First_Name = scan(Region, 1);
	Last_Name = scan(Region, 2);
RUN;


/* 变量 + 表达式;*/
filename exfiles "E:\project\tools\SAS\data";
DATA sasuser.sales;
	length Name $20;
	infile exfiles(sales) dsd;
	input Emp_ID $ Name $ Dept $ Sales:COMMA10.;
	format Sales DOLLAR10.;
RUN;
DATA work.sales_sum;
	set sasuser.sales;
	Total_Sales + Sales;
	format Total_Sales DOLLAR10.;
RUN;
PROC PRINT data = work.sales_sum;
	title "Total Sales";
RUN;


DATA work.shoes_subsidiary (drop = Sales);
	set sashelp.shoes (keep = Region Subsidiary Sales);
	by Region Subsidiary;

	if First.Subsidiary then
		Total_Sales_Subsidiary = 0;
	Total_Sales_Subsidiary + Sales;

	if Last.Subsidiary;
	format Total_Sales_Subsidiary DOLLAR10.;
RUN;
PROC PRINT data = work.shoes_subsidiary noobs;
	title "Shoes Subsidiary";
RUN;

/* RETAIN */
DATA work.sales_retain;
	set sasuser.Sales;
	retain Total_Sales 0;
	Total_Sales = Total_Sales + Sales;
	format Total_Sales DOLLAR10.;
RUN;
PROC PRINT data = work.sales_retain;
	title "Sales Retain";
RUN;



/* SUM(,) */
DATA work.sales_sumfunc;
	set sasuser.Sales;
	retain Total_Sales 0;
	Total_Sales = sum(Total_Sales, Sales);
	format Total_Sales DOLLAR10.;
RUN;
PROC PRINT data = work.sales_sumfunc noobs;
	title "Sales Sumfunc";
RUN;

/**************************************************************
 * 3.4 循环和数组
 ***************************************************************/
DATA work.square;
	do x = 1 to 10 by 1;
		y = x ** 2;
		output;
	end;
RUN;
PROC PRINT data = work.square noobs;
	title "Square";
RUN;



/**************************************************************
 * 3.5 函数
 ***************************************************************/
filename exfiles "E:\project\tools\SAS\data";
DATA sasuser.shop;
	length Shop $200;
	length Street $20;
	length City $20;
	length State $2;
	infile exfiles(shop) dsd;
	input Shop $ Telephone $ Street $ City $ State $ Zip:COMMA10.;
RUN;


DATA work.shop_fulladdr1;
	set sasuser.shop (drop = Telephone Zip);
	Full_Address = Street || ', ' || City  || ', ' || State;
	drop Street City State;
RUN;

PROC PRINT data = work.shop_fulladdr1;
	title 'Shop Full Address 1';
RUN;


DATA work.shop_fulladdr2;
	set sasuser.shop (drop = Telephone Zip);
	Full_Address = trim(Street) || ', ' || trim(City) || ',' || trim(State);
	drop Street City State;
RUN;
PROC PRINT data = work.shop_fulladdr2;
	title 'Shop Full Address 2';
RUN;


DATA work.shop_fulladdr3;
	set sasuser.shop (drop = Telephone Zip);
	Full_Address = catx(", ", Street, City, State);
	drop Street City State;
RUN;
ods pdf file = "E:\project\tools\SAS\data\full_address.pdf";
PROC PRINT data = work.shop_fulladdr3;
	title 'Shop Full Address 3';
RUN;
ods pdf close;


