#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;

my $pwd = $ENV{'PWD'};  #获取当前路径

sub dealpath($){
    my $path = $_[0];
    my @allpath = split(/;/,$path);
    my (@path,@LibID,@LaneID);
    foreach my $eachpath(@allpath){
        if($eachpath =~ /(.*){(.*)\((L\w.*)\)}/){
            push(@path,$1);
            push(@LibID,$2);
            push(@LaneID,$3);
        }
    }
    foreach my $i(0 .. $#allpath-1){
        foreach my $j($i+1 .. $#allpath){
            next if($LibID[$i] ne $LibID[$j]);
            my @allLane_i = split(/,/, $LaneID[$i]);
            my @allLane_j = split(/,/, $LaneID[$j]);
            if ((scalar(@allLane_i) == 1) and (scalar(@allLane_j) == 1)){
                if($LaneID[$i] eq $LaneID[$j]){
                    system("mkdir -p $pwd/00RawData");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_1.fq.gz $pwd/00RawData/$LibID[$j]_$LaneID[$j]-$j\_1.fq.gz");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_1.adapter.list.gz $pwd/00RawData/$LibID[$j]_$LaneID[$j]-$j\_1.adapter.list.gz");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_1.adap.stat $pwd/00RawData/$LibID[$j]_$LaneID[$j]-$j\_1.adap.stat");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_2.fq.gz $pwd/00RawData/$LibID[$j]_$LaneID[$j]-$j\_2.fq.gz");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_2.adapter.list.gz $pwd/00RawData/$LibID[$j]_$LaneID[$j]-$j\_2.adapter.list.gz");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_2.adap.stat $pwd/00RawData/$LibID[$j]_$LaneID[$j]-$j\_2.adap.stat");
                    $path[$j] = "$pwd/00RawData";
                    $LaneID[$j] = "$LaneID[$j]-$j";
                }
            }else{
                foreach my $ii(0 .. $#allLane_i){
                    foreach my $jj(0 .. $#allLane_j){
                        if($allLane_i[$ii] eq $allLane_j[$jj]){
                            system("mkdir -p $pwd/00RawData");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_1.fq.gz $pwd/00RawData/$LibID[$j]_$allLane_j[$jj]-$j\_1.fq.gz");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_1.adapter.list.gz $pwd/00RawData/$LibID[$j]_$allLane_j[$jj]-$j\_1.adapter.list.gz");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_1.adap.stat $pwd/00RawData/$LibID[$j]_$allLane_j[$jj]-$j\_1.adap.stat");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_2.fq.gz $pwd/00RawData/$LibID[$j]_$allLane_j[$jj]-$j\_2.fq.gz");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_2.adapter.list.gz $pwd/00RawData/$LibID[$j]_$allLane_j[$jj]-$j\_2.adapter.list.gz");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_2.adap.stat $pwd/00RawData/$LibID[$j]_$allLane_j[$jj]-$j\_2.adap.stat");
                            $path[$j] = "$pwd/00RawData";
                            $allLane_j[$jj] = "$allLane_j[$jj]-$j";
                       }
                    }
                }
                $LaneID[$j] = join(",",@allLane_j);
            }
        }
    }
    my @newallpath = ();
    foreach my $k(0 .. $#path){
        push(@newallpath,"$path[$k]\{$LibID[$k]\($LaneID[$k]\)\}");
    }
    my $newpath = join(";",@newallpath);
    return $newpath;
}
sub main(){
    die"Usage:  perl generateNewcfg.pl  old.cfg > new.cfg\n" if(@ARGV < 1);  #如果没有参数，打印程序的使用说明
    open IN, "<$ARGV[0]" or die "$!\n";  #第一个参数编号为0
    while(<IN>){
        chomp;
        if(/^检测产品/){
            print $_,"\n";
            next;
        }
        next if(/^\n/);
        my @line = split(/\t/,$_);
        my $path =  $line[17];
        if($path =~ /;/){
            my $newpath = &dealpath($path);
            $line[17] = $newpath;
            my $newline = join("\t",@line);
            print $newline,"\n";
        }else{
            print $_,"\n";
        }     
    }
    close IN;
    return 1;
}

exit(0)if(&main()); #程序的main()入口
