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

/* ������ݼ�������Ϣ*/
PROC CONTENTS data = saslib.Inventory;
RUN;

ODS LISTING;

TITLE '�ֿ���';

/* ������� */
PROC PRINT data = saslib.Inventory;
RUN;

/*���������*/
PROC PRINT data = saslib.Inventory NOOBS;
RUN;

ODS LISTING CLOSE;
