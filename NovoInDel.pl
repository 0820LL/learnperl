#!/usr/bin/perl -w 
use strict;
use Getopt::Long;
use List::Util qw/sum/;

my ($tu,$wbc,$chr,$tdp,$wdp,$mut,$tfre,$wfre,$help,$prefix);
GetOptions(
        "t:s"   =>  \$tu,
        "wbc:s" =>  \$wbc,
        "pre:s" =>  \$prefix,
        "chr:s" =>  \$chr,
        "tdp:s" =>  \$tdp,
        "wdp:s" =>  \$wdp,
        "mut:s" =>  \$mut,
        "tfre:s"=>  \$tfre,
        "wfre:s"=>  \$wfre,
        "h"     =>  \$help,
);
&check;
#========default parameters=======
#die "wrong type info \n" if ((not $type=~m/snp/i ) && (not $type=~m/indel/i));
$tdp||=0;
$wdp||=0;
$mut||=0;
$tfre||=0;
$wfre||=1;
my $out1="$prefix-all.xls";
my $out2="$prefix-somatic.xls";
my $out3="$prefix-somatic.raw.vcf";

my (%normal,%tumor,%Nvar,%Tvar,$head,%tumor_alter);

#============  main =============
open WBC,"gzip -dc $wbc|" || die "$wbc $!\n";
my @wbc_all=<WBC>;
close WBC;

foreach my $line(@wbc_all)
{
    next if($line=~/^\#/);
    chomp $line;
    my $mark=&readin("all",\%normal,"info",$line,"indel",\%Nvar);
    last if($mark==2);
}
@wbc_all=qw//;

open TU,"gzip -dc $tu|" || die "$tu $!\n";
my @tumor_all=<TU>;
close TU;
foreach(@tumor_all)
{
    if(/^\#/){$head.=$_;next}
    chomp;
    my $mark=&readin("all",\%tumor,"info",$_,"indel",\%Tvar,"record",\%tumor_alter);
    last if($mark==2);
}
@tumor_all=qw//;

my $output1=
"##chr:      reference chromosome\n##position: mutation position\n##Nref:     refernece base(s) at normal sample mutation site\n##Nalt:     normal sample mutation base\n##NDP:      normal sample high-quality bases\n##NDP4:     normal sample  high-quality ref-forward bases, ref-reverse, alt-forward and alt-reverse bases\n##Nfmut:    normal sample mutation rate\n##Ntype:    normal sample mutation type(insertion or deletion)\n##Tref:     refernece base(s) at tumor sample mutation site\n##Talt:     tumor sample mutation base\n##TDP:      tumor sample high-quality bases\n##TDP4:     tumor sample  high-quality ref-forward bases, ref-reverse, alt-forward and alt-reverse bases\n##Tfmut:    tumor sample mutation rate\n##Ttype:    tumor sample mutation type(insertion or deletion)\nchr\tposition\tNref\tNalt\tNDP\tNDP4\tNfmut\tNtype\tTref\tTalt\tTDP\tTDP4\tTfmut\tTtype\tmarker\n";
my $output2=$output1;
my $output3;

foreach my $chrkey(keys %Tvar)
{
    foreach my $poskey(keys %{$Tvar{$chrkey}})
    {
        if (exists $Nvar{$chrkey}{$poskey})
        {
            $output1.="$chrkey\t$poskey\t".join("\t",@{$normal{$chrkey}{$poskey}})."\t".join("\t",@{$tumor{$chrkey}{$poskey}})."\tgermline\n";
            delete $Nvar{$chrkey}{$poskey};
        }
        elsif(exists $normal{$chrkey}{$poskey})
        {
            my (@Nref,@Nalt,@NDP,@NDP4,@Nfmut,@Ntype);
            my $char=${$tumor{$chrkey}{$poskey}}[1];
            $char=${$tumor{$chrkey}{$poskey}}[0] if(${$tumor{$chrkey}{$poskey}}[5]=~/del/);
            for my $i($poskey..($poskey+length($char)))
            {
                for my $n(0..5)
                {
                    ${$normal{$chrkey}{$i}}[$n]||="0";
                }
                my $wbc_dp=${$normal{$chrkey}{$i}}[2];
                next if($wbc_dp<$wdp); #白细胞总深度大于
                my @dp_wbc=split/\,/,${$normal{$chrkey}{$i}}[3];
                my $mutation_wbc=$dp_wbc[2]+$dp_wbc[3];
                my $wbc_freq=$mutation_wbc/$wbc_dp;
                next if ($wbc_freq > $wfre); #白细胞突变频率小于
                push @Nref,${$normal{$chrkey}{$i}}[0];
                push @Nalt,${$normal{$chrkey}{$i}}[1];
                push @NDP, ${$normal{$chrkey}{$i}}[2];
                push @NDP4,${$normal{$chrkey}{$i}}[3];
                push @Nfmut,${$normal{$chrkey}{$i}}[4];
                push @Ntype,${$normal{$chrkey}{$i}}[5];
            }
            $output1.="$chrkey\t$poskey\t".join("\t",join(";",@Nref),join(";",@Nalt),join(";",@NDP),join(";",@NDP4),join(";",@Nfmut),join(";",@Ntype))."\t".join("\t",@{$tumor{$chrkey}{$poskey}})."\tsomatic\n";
            my $tumor_dp=${$tumor{$chrkey}{$poskey}}[2];
            next if($tumor_dp<$tdp); # tumor总深度大于

            my @dp_tumor=split/\,/,${$tumor{$chrkey}{$poskey}}[3];
            my $mutation_num=$dp_tumor[2]+$dp_tumor[3];
            next if($mutation_num < $mut); #突变型支持数大于

            my $tumor_freq=$mutation_num/$tumor_dp;
            next if($tumor_freq < $tfre); #tumor突变型频率大于

            $output2.="$chrkey\t$poskey\t".join("\t",join(";",@Nref),join(";",@Nalt),join(";",@NDP),join(";",@NDP4),join(";",@Nfmut),join(";",@Ntype))."\t".join("\t",@{$tumor{$chrkey}{$poskey}})."\tsomatic\n";
            $output3.="$tumor_alter{$chrkey}{$poskey}\n";
        }
        else
        {
            $output1.="$chrkey\t$poskey\t.\t.\t.\t.\t.\t.\t".join("\t",@{$tumor{$chrkey}{$poskey}})."\tunknown\n";
        }
    }
}
foreach my $chrkey2(keys %Nvar)
{
    foreach my $poskey2(keys %{$Nvar{$chrkey2}})
    {
        if(exists $tumor{$chrkey2}{$poskey2})
        {
            my (@Tref,@Talt,@TDP,@TDP4,@Tfmut,@Ttype);
            my $char=${$normal{$chrkey2}{$poskey2}}[1];
            $char=${$normal{$chrkey2}{$poskey2}}[0] if(${$normal{$chrkey2}{$poskey2}}[5]=~/del/);
            for my $j($poskey2..($poskey2+length($char)))
            {
               (defined ${$normal{$chrkey2}{$j}}[0])?(push @Tref, ${$normal{$chrkey2}{$j}}[0]):(push @Tref,"0");
               (defined ${$normal{$chrkey2}{$j}}[1])?(push @Talt, ${$normal{$chrkey2}{$j}}[1]):(push @Talt,"0");
               (defined ${$normal{$chrkey2}{$j}}[2])?(push @TDP,  ${$normal{$chrkey2}{$j}}[2]):(push @TDP,"0");
               (defined ${$normal{$chrkey2}{$j}}[3])?(push @TDP4, ${$normal{$chrkey2}{$j}}[3]):(push @TDP4,"0");
               (defined ${$normal{$chrkey2}{$j}}[4])?(push @Tfmut,${$normal{$chrkey2}{$j}}[4]):(push @Tfmut,"0");
               (defined ${$normal{$chrkey2}{$j}}[5])?(push @Ttype,${$normal{$chrkey2}{$j}}[5]):(push @Ttype,"0");
            }
            $output1.="$chrkey2\t$poskey2\t".join("\t",@{$normal{$chrkey2}{$poskey2}})."\t".join("\t",join(";",@Tref),join(";",@Talt),join(";",@TDP),join(";",@TDP4),join(";",@Tfmut)."\t".join(";",@Ttype))."\tLOH\n";
        }
        else
        {
            $output1.="$chrkey2\t$poskey2\t".join("\t",@{$normal{$chrkey2}{$poskey2}})."\t\.\t\.\t\.\t\.\t\.\t\.\tunknown\n";
        }
    }
}
open OUT1,">$out1" || die "$out1 $!\n";
print OUT1 $output1;
close OUT1;
open OUT2,">$out2" || die "$out2 $!\n";
print OUT2 $output2;
close OUT2;
if(length($output3) > 0)
{
    $output3=$head.$output3;
    open OUT3,">$out3" || die "$out3 $!\n";
    print OUT3 $output3;
    close OUT3;
}

#================sub programs==============
sub readin
{
    my %parameter=@_;
    my @info;
    ($parameter{"info"}=~/\t/)?(@info=split /\t/,$parameter{"info"}):(@info=split /\s+/,$parameter{"info"});
    if($chr && $info[0] ne $chr)
    {
        return "3" if ($info[0] < $chr);
        return "2" if ($info[0] > $chr);
    }
    my ($dp1,$dp2,$dp3,$dp4)=($info[7]=~/DP4=(\d+),(\d+),(\d+),(\d+)/);
    return "3" if( (!defined $dp1) || (! defined $dp2) || (! defined $dp3) || (! defined $dp4));
    my $dp=$dp1+$dp2+$dp3+$dp4;
    my $DP4="$dp1,$dp2,$dp3,$dp4";
    my $fmut=sprintf("%.3f",($dp3+$dp4)/$dp);
    my $type;
    if(length($info[3])>length($info[4]))
    {
        $type="deletion";
    }
    elsif(length($info[3])<length($info[4]))
    {
        $type="insertion";
    }
    else
    {
        $type=".";
    }
    my $var;
    if($info[7]=~/^INDEL/)
    {
        $var="indel";
        ${$parameter{"indel"}}{$info[0]}{$info[1]}=1;
    }
    elsif($info[4] ne "."){$var="snp"; }
    else{$var="ref";}
    my @temp=($info[3],$info[4],$dp,$DP4,$fmut,$type);
    ${$parameter{"all"}}{$info[0]}{$info[1]}=[@temp];
    ${$parameter{"record"}}{$info[0]}{$info[1]}=$parameter{"info"} if(defined $parameter{"record"});
    return 1;
}

sub check{
die  "
Usage   used to filter somatic insertion or deletion for tumor and wbc(germ cell) raw vcf files
        the vcf files should be compression into .gz format
Author  wuxiaomeng\@novogene.cn
Version 1.1
Update  2014-10-23

perl $0 [options]
    -t     <char>  *tumer Raw.vcf.gz file
    -wbc   <char>  *wbc Raw.vcf.gz file
    -pre   <char>  *prefix of output file name
    -chr   <int>   just filter this chromsome and show filter result
    -tdp   <int>   minimal tumer total depth  
    -wdp   <int>   minimal wbc total depth
    -mut   <int>   minimal mutation reads number
    -tfre  <num>   minimal tumer mutation frequency, like 0.05
    -wfre  <num>   maximum wbc mutation frequency, like 0.01
    -h             show help information
the * marked parameters are required for analysis

Example 
    perl InDel_samtools.pl  -t  ../lb/10012/T010012/03.SnpIndel/germline-samtools/T010012.Raw.vcf.gz  -wbc ../lb/10012/Wbc010012/03.SnpIndel/germline-samtools/Wbc010012.Raw.vcf.gz -ty indel -out ./test -chr 7 -tdp 15 -wdp 6 -mut 5 -tfre 0.05 -wfre 0.01
    " if(!$tu || !$wbc || !$prefix || $help);
}
