* Create a SAS data set named distance;
* Convert miles to kilometers;
DATA distance;
    Miles = 26.22;
    Kilometers = 1.61 * Miles;
RUN;
* Print the results;
PROC PRINT DATA = distance;
RUN;
