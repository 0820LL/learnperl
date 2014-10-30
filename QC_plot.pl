#!/usr/bin/perl
use strict;
use warnings;
use Cwd;


die "perl $0 <indir> <sample name>" unless @ARGV==2;
#need files: sample.stat clean_sample.GC clean_sample.QM clean_sample.QD clean_sample.GC
#out files: .raw_reads_classification.p* clean_sample.QM.p* clean_sample.Error.p* clean_sample.QD.p* clean_sample.GC.p* 

my $indir=$ARGV[0];
my $name = $ARGV[1];
&plotR($indir, $name, "raw");
&plotR($indir, $name, "clean");
sub plotR {
	my ($indir, $name, $type) = @_;
my $R =<< "END";  #表示下一行开始，直到遇见END为止，所有的字符都按照指定的格式存入变量$R中。
#-----------------------
library(ggplot2)
library(reshape2)
#
#class
#
setwd("$indir")
#------------------------------------------------
#
# QM
#
df<-read.table("$type\_$name.QM",sep="\t",head=F)
colnames(df)=c("pos","Q","E")
df\$pos<-df\$pos+1
middle=(max(df\$pos))/2
p <- ggplot(df,aes(x=pos,y=Q))+
geom_point(size = I(1),colour="#66C2A5")+
#geom_line(colour="#66C2A5",size=1)+
xlab("Position along reads") + ylab("Quality score")+
ylim(0,45)+
opts(title="Quality score distribution along reads ($name)")+
scale_x_discrete(breaks=seq(0,max(df\$pos),20),labels=seq(0,max(df\$pos),20))+
geom_vline(xintercept = middle,colour="#377EB8",linetype="dashed")

ggsave(filename="$type\_$name.QM.pdf",plot=p)
ggsave(filename="$type\_$name.QM.png",type="cairo-png",plot=p)
#------------------------------------------------
#
# Error
#
p <- ggplot(df,aes(x=pos,y=E,ymin=0,ymax=E))+
geom_linerange(colour="#66C2A5",size=0.5)+
xlab("Position along reads") + ylab("% Error rate")+
opts(title="Error rate distribution along reads ($name)")+
geom_vline(xintercept = middle,colour="#377EB8",linetype="dashed")

ggsave(filename="$type\_$name.Error.pdf",plot=p)
ggsave(filename="$type\_$name.Error.png",type="cairo-png",plot=p)
#------------------------------------------------
# QD
#
df<-read.table("$type\_$name.QD",sep="\t",head=F)
colnames(df)=c("Q","N")
df\$N<-df\$N/1000000

p <- ggplot(df, aes(x=Q, y=N))+
geom_point(size = I(3),colour="#66C2A5")+
geom_line(size = 1,colour="#66C2A5")+
xlab("Quality score") + ylab("Number of bases (M)")+
opts(title="Quality score distribution ($name)")
ggsave(filename="$type\_$name.QD.pdf",plot=p)
ggsave(filename="$type\_$name.QD.png",type="cairo-png",plot=p)
#------------------------------------------------
# GC
#
data<-read.table("$type\_$name.GC",sep="\t",head=F)
df<-as.data.frame(cbind(data[,4],data[,7],data[,10],data[,13],data[,16]))
colnames(df)<-c("A","T","G","C","N")
pos<-data[,1]+1
pos<-as.data.frame(rep(pos,5))
middle=(max(data[,1]+1))/2

mdf<-melt(df,measure=colnames(df))
mdf<-cbind(mdf,pos)
colnames(mdf)<-c("type","percent","pos")

p <- ggplot(mdf, aes(x=pos, y=percent, group=type))+
geom_line(aes(colour = type),size=0.5)+
scale_x_discrete(breaks=seq(0,max(data[,1]+1),20),labels=seq(0,max(data[,1]+1),20))+
coord_cartesian(ylim=c(0,50))+
xlab("Position along reads") + ylab("Percent of bases")+
opts(title="Bases content along reads ($name)")+
geom_vline(xintercept = middle,colour="#377EB8",linetype="dashed")

ggsave(filename="$type\_$name.GC.pdf",plot=p)
ggsave(filename="$type\_$name.GC.png",type="cairo-png",plot=p)

#===============================================
END

open R,">$indir/$name\_QC_${type}_plot.R" or die $!;
print R $R;
close R;
system "/PUBLIC/software/public/System/R-2.15.3/bin/R -f $indir/$name\_QC_${type}_plot.R";
}
