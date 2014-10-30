#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;

sub dealpath($){
    my $outdir = $ARGV[1];
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
    foreach my $i(0 .. $#allpath-1){  #$#allpath-1取数组最后一个元素的下标
        foreach my $j($i+1 .. $#allpath){
            next if($LibID[$i] ne $LibID[$j]);
            my @allLane_i = split(/,/, $LaneID[$i]);
            my @allLane_j = split(/,/, $LaneID[$j]);
            if ((scalar(@allLane_i) == 1) and (scalar(@allLane_j) == 1)){
                if($LaneID[$i] eq $LaneID[$j]){
                    system("mkdir -p $outdir/00.RawData/$LibID[$j]");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_1.fq.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$LaneID[$j]$j\_1.fq.gz");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_1.adapter.list.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$LaneID[$j]$j\_1.adapter.list.gz");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_2.fq.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$LaneID[$j]$j\_2.fq.gz");
                    system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$LaneID[$j]_2.adapter.list.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$LaneID[$j]$j\_2.adapter.list.gz");
                    $path[$j] = "$outdir/00.RawData";
                    $LaneID[$j] = "$LaneID[$j]$j";
                }
            }else{
                foreach my $ii(0 .. $#allLane_i){
                    foreach my $jj(0 .. $#allLane_j){
                        if($allLane_i[$ii] eq $allLane_j[$jj]){
                            system("mkdir -p $outdir/00.RawData/$LibID[$j]");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_1.fq.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]$j\_1.fq.gz");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_1.adapter.list.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]$j\_1.adapter.list.gz");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_2.fq.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]$j\_2.fq.gz");
                            system("ln -s $path[$j]/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]_2.adapter.list.gz $outdir/00.RawData/$LibID[$j]/$LibID[$j]_$allLane_j[$jj]$j\_2.adapter.list.gz");
                            $path[$j] = "$outdir/00.RawData";
                            $allLane_j[$jj] = "$allLane_j[$jj]$j";
                       }
                    }
                }
                $LaneID[$j] = join(",",@allLane_j);
            }
        }
    }
    my @newallpath = ();  #建立空数组
    foreach my $k(0 .. $#path){
        push(@newallpath,"$path[$k]\{$LibID[$k]\($LaneID[$k]\)\}");
    }
    my $newpath = join(";",@newallpath);
    return $newpath;
}
sub comp($$){
    my $old = $_[0]; #将传递过来的数组地址赋值给变量$old
    my $new = $_[1];
    my $old_1 = join("\n",@$old);  #解析引用
    my $new_1 = join("\n",@$new);
    if($old_1 eq $new_1){
        return 0;
    }else{
        return 1;
    }
}
sub main(){
    die"Usage:  perl generateNewcfg.pl old.cfg Outdir\n" if(@ARGV < 1);
    open IN, "<$ARGV[0]" or die "$!\n";
    my @old = ();
    my @new = ();
    my $flag = -1;
    while(<IN>){
        chomp;
        push(@old,$_);
        my $fistline;
        if(/^检测产品/){
            push(@new, $_);
            next;
        }
        next if(/^\n/);
        my @line = split(/\t/,$_);
        my $path =  $line[17];
        if($path =~ /;/){
            my $newpath = &dealpath($path);
            $line[17] = $newpath;
            my $newline = join("\t",@line);
            push(@new,$newline);
        }else{
            push(@new,$_);
        }     
    }
    close IN;
    $flag = &comp(\@old,\@new);  #将数组@old和@new的地址传递给子程序comp
    print $ARGV[0]."\n" if($flag == 0);
    if($flag == 1){
        my $name;
        if($ARGV[0] =~ /.*\/(.*\.cfg)$/){
            $name = $1;
        }else{
            $name = $ARGV[0];
        }
        open OUT, ">$ARGV[1]/$name" or die "$!\n";
        foreach my $line(@new){
            print OUT "$line\n";
        }
        close OUT;
        print $ARGV[1]."/".$name."\n" if ($flag == 1); 
    }
    return 1;
}

exit(0)if(&main());
