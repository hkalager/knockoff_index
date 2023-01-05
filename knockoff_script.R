#### Knockoff script developed by Arman Hassanniakalager
# This script is to be called in running Knockoff filter

#### Last reviewed 05/01/2023

#install.packages("knockoff")
library(knockoff)
fdr_level=.1
setwd("~/Documents/GitHub/stock_port")
X_ser<- read.csv(file = 'X_ser.csv',header=TRUE)
if (colnames(X_ser)[1]=="date")
{
  colnames(X_ser)=c("Date",colnames(X_ser)[2:dim(X_ser)[2]])
}
rownames(X_ser) <- X_ser$Date
X_ser$Date <- NULL
X_ser=data.matrix(X_ser)
#X_ser=X_ser[1:50]

Y_ser<- read.csv(file = 'Y_ser.csv',header=TRUE)

if (colnames(Y_ser)[1]=="date")
{
  colnames(Y_ser)=c("Date","return")
}

rownames(Y_ser) <- Y_ser$Date
Y_ser$Date <- NULL
y=as.numeric(Y_ser$return)
found_set=FALSE
while (found_set==FALSE)
  {
    n=dim(X_ser)[1]
    p=dim(X_ser)[2]
    set.seed(0)
    if (n>2*p) {
      result = knockoff.filter(X=X_ser, y=y,fdr=fdr_level,
                               create.fixed)
    } else {
        result = knockoff.filter(X_ser, y,fdr=fdr_level)}
    
    found_set=(length(result$selected)>=1)
    if (found_set==FALSE)
      {fdr_level=fdr_level+0.05}
  }

selected_inputs=result$selected
df<-data.frame(as.list(selected_inputs))
write.csv(df,file='selected_knockoffs.csv',row.names = FALSE)
