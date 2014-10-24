#!/usr/bin/perl -w
use strict;
use Getopt::Long;
my ($info,$reform,$prefix,$help);
my ($double,$mindp,$minfre,$minmut);
GetOptions(
    "info:s"    =>  \$info,
    "reform:s"  =>  \$reform,
    "pre:s"     =>  \$prefix,
    "h"         =>  \$help,
    "double"    =>  \$double,
    "dp:s"      =>  \$mindp,
    "fre:s"     =>  \$minfre,
    "mut:s"     =>  \$minmut,
    );
&check;

$double||=1;
$mindp||=50;
$minfre||=0.05;
$minmut||=5;
#my ($reform,$snp)=@ARGV;

#my $ttdb = "/PROJ/CR/share/pipeline/cancerPipelineV2/DB/medicine/PMv1/myCancerGenomeDB_20140331v2.xls";
#my %ttdb;
#open TTDB, "<", "$ttdb" or die $!;
#while(my $line = <TTDB>)
#{
#	chomp $line;
#	my @lines = split /\t/, $line;
#	next if($lines[3] eq '.' || $lines[4] eq '.' || !($lines[7] =~ /[ATCG]\/[ATCG]/));
#	$lines[7] =~ /([ATCG])\/([ATCG])/;
#	my $mutstr = $lines[3].':'.$lines[4].':'.$1.':'.$2;
#	$ttdb{$mutstr} = $lines[0].'_'.$lines[2].'_'.$lines[10];
#}
#close TTDB;

open INFO,"<$info" || die "$!\n";
my %info;  #key1:chr, key2:site, value1: ref, value2: RT
my @info_all=<INFO>;
close INFO;

foreach(@info_all)
{
	chomp;
	my @temp=split /\t/;
#	my ($var)=($temp[3]=~/^(\w)\|/);
#	my $mut=$temp[0].":".$temp[1].":".$temp[2].":".$var;
#	$info{$mut}=$temp[3];
    $info{$temp[0]}{$temp[1]}=$temp[3];
}

my %reform;
open REFORM,"<$reform" || die "$!\n";
my @reform_all=<REFORM>;
close REFORM;

my $out_info="";
my $out_content="CHROM\tPOS\tID\tREF\tALT\tFREQ\tDP4\tQUAL\tFILTER\tFunc\tGene\tExonicFunc\tAAChange\t1000g2012apr_all\tsnp138\tcosmic68\tclinvar_20140303\tINFO\tFORMAT\tN\tT\n";
shift @reform_all;
foreach my $rf_tmp(@reform_all)
{
	chomp $rf_tmp;
	my @temp=split /\t/,$rf_tmp;
    my ($dp1,$dp2,$dp3,$dp4)=($info{$temp[0]}{$temp[1]}=~/\((\d+),(\d+),(\d+),(\d+)\)/);
    my $DP=($dp1+$dp2+$dp3+$dp4);
    my $mut=($dp3+$dp4);
    my $fre=$mut/$DP;
    next if($double && ($dp3==0 || $dp4==0));  #double strain
    next if ( $DP< $mindp || $mut<$minmut || $mut/$DP< $minfre);
    #$out_content.= "$mut\t$DP\t".$mut/$DP."\n";
    #$out_content.="$rf_tmp\t$info{$temp[0]}{$temp[1]}\n";
    $fre=sprintf("%.3f",$fre);
    
    my ($chr,$pos,$id,$ref,$alt)=@temp[0..4];
    for(0..4){shift @temp};
    $out_content.="$chr\t$pos\t$id\t$ref\t$alt\t$fre\t$dp1,$dp2,$dp3,$dp4\t".join("\t",@temp)."\n";
    $out_info.="$chr\t$pos\t$ref\t";
    $out_info.=$info{$chr}{$pos}."\n";
#    $out_content.="$info{$temp[0]}{$temp[1]}\t$rf_tmp\n";
#	my $mut="$temp[0]:$temp[1]:$temp[3]:$temp[4]";
#	my @a=($temp[3],$temp[15],$info{$mut},$temp[12],$temp[8],$temp[7],$temp[9],$temp[10],$temp[13],$temp[14],$temp[11]);
#	$reform{$mut}=\@a;
}

#foreach my $key(sort{$a cmp $b} keys %reform)
#{
#	my ($chr,$site,$ref,$var)=split /\:/,$key;
#    if(exists $ttdb{$key})
#    {
#        print "$chr\t$site\t",join("\t",@{$reform{$key}}),"\t$ttdb{$key}\n";
#    }
#    else
#    {
#        print "$chr\t$site\t",join("\t",@{$reform{$key}}),"\t-\n";
#    }
#}
open OUT1,">$prefix.reform.select.txt" || die "$prefix.reform.select.txt $!\n";
print OUT1 $out_content;
close OUT1;

open OUT2,">$prefix.snp.select.info" || die "$prefix.snp.select.info $!\n";
print OUT2 $out_info;
close OUT2;

sub check
{
die "
Usage    used to filter somatic snp
Author   wuxiaomeng\@novogene.com
Version  v1.1
Update   2014-10-23

perl $0 [options]
    -reform <char>   *reform.txt
    -info   <char>   *snp.info
    -pre    <char>   *output file path and prefix
    -double <0|1>    1 for double strain support variation[default=1]
    -dp     <int>    minimal depth[default=50]
    -fre    <num>    minimal mutation frequency[default=0.05]
    -mut    <int>    minimal mmutation reads number[default=5]
the * marked parameters are required for analysis

Input
         .reform.txt
         .snp.info

Output
         .reform.select.txt
         .snp.select.info

Example
perl FilterSomaticSNP_v1.1.pl  -reform T010012.Wbc010012.filted.mutect.SNP.reformated.txt -info T010012.Wbc010012.filted.mutect.SNP.info -out test.snp -double 1 -dp 50 -fre 0.05 -mut 5
\n" if(!$info || (! -f $info) || !$reform || (! -f $reform) || !$prefix);
}
