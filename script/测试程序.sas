LIBNAME saslib BASE 'E:\project\tools\SAS\data';

DATA saslib.Inventory;
INPUT Product_ID $ Instock Price;
DATALINES;
P001R 12 125.00
P003T 34 40.00
P301M 23 500.00
PC02M 12 100.00
;
RUN;

/* 输出数据集属性信息*/
PROC CONTENTS data = saslib.Inventory;
RUN;

ODS LISTING;

TITLE '仓库库存';

/* 输出行名 */
PROC PRINT data = saslib.Inventory;
RUN;

/*不输出行名*/
PROC PRINT data = saslib.Inventory NOOBS;
RUN;

ODS LISTING CLOSE;
