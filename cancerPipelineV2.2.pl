#!/usr/bin/perl

=pod

=head1 Name
	cancerPipeline.pl

=head1 Synopsis
	A pipeline for detect somatic cancer mutations.

=head1 Description
	Reading Raw data List, it will do qc, align, SNP indel detect and Genarating report automaticlly.

=head1 Usage
	perl cancerPipeline.pl --xml pmp=pmp.xml --xml pms=pms.xml --xml lb=lb.xml --cfg Data.cfg --cts ContactsList.xls --out . 

=head1 Options
	--xml	<string>	XML config file for different project Type. Format: projectType=XMLfile
	--cfg	<string>	Config file of Data path and Custom Infomation. utf-8 format.
	--cts	<string>	Contacts file of project manager. Format: Name E-mail CellphoneNumber. utf-8 format.
	--out	<string>	Output directory. [default: ./]
	--sh			If Specified, the program will generate a shell directory In your outDir
	--inexe			If Specified, The program will not run the sjm automatically.

=head1 Version
	V2.2; 20140924; CaoYinchuan;caoyinchuan@novogene.cn;

=cut

use warnings;
use strict;
use XML::Simple qw(:strict);
use Getopt::Long;
use File::Path qw(make_path);
use FindBin qw($RealBin);
use Proc::ProcessTable;
use MIME::Lite;
use Data::Dumper;


MIME::Lite->send("sendmail", "/usr/sbin/sendmail -t -oi -oem");
my %opt;
GetOptions(\%opt, qw(xml=s% cfg=s out=s cts=s sh inexe));
die `pod2text $0` unless ($opt{'cfg'} and $opt{'xml'});
chomp($opt{'out'} = `pwd`) unless (exists $opt{'out'});
my ($cfgFile, $outDir) = ($opt{'cfg'}, $opt{'out'});
$outDir = &getRealDir($outDir);
make_path("$outDir", {verbose => 1, mode => 0755});
chomp($opt{'cfg'} = `perl $RealBin/Bin/checkCfg.pl $opt{'cfg'} $outDir`);
my $outPrefix = &getBasename($cfgFile);
my %contacts = &LoadingContacts($opt{'cts'});
make_path("$outDir/Tasks/$outPrefix/log", {verbose => 1, mode => 0755});
my ($data, $info, $email, $phone, $customInfo) = &LoadingCfgFile($cfgFile);
print STDERR "Waiting for all files ready ...\n";
&waitForData($data);
print STDERR "All files has been ready\n";
my (@Tasks, %taskHash);
foreach my $ProjectType (keys %{$data}) {
	next unless (exists ${$opt{'xml'}}{$ProjectType});
	my $cfg = XMLin($opt{'xml'}->{$ProjectType}, KeyAttr => {}, ForceArray => ['Task', 'Function'], SuppressEmpty => undef);
	foreach my $t (@{$cfg->{'Task'}}) {
		$t->{'Queue'} = $cfg->{'ENV'}->{'Queue'} if ($cfg->{'ENV'}->{'Queue'});
		$t->{'Project'} = $cfg->{'ENV'}->{'Project'} if ($cfg->{'ENV'}->{'Project'});
		$t->{'Command'} = "source $cfg->{'ENV'}->{'Environment'}\n" . $t->{'Command'} if ($cfg->{'ENV'}->{'Environment'});
	}
	foreach my $f (@{$cfg->{'Function'}}) {
		foreach my $t (@{$f->{'Task'}}) {
			$t->{'Queue'} = $cfg->{'ENV'}->{'Queue'} if ($cfg->{'ENV'}->{'Queue'});
			$t->{'Project'} = $cfg->{'ENV'}->{'Project'} if ($cfg->{'ENV'}->{'Project'});
			$t->{'Command'} = "source $cfg->{'ENV'}->{'Environment'}\n" . $t->{'Command'} if ($cfg->{'ENV'}->{'Environment'});
		}
	}
	my %value = (	'$OutDir' => $outDir, 
			'$ProjectType' => $ProjectType, 
			'$Genome' => $cfg->{'ENV'}->{'Genome'},
			'$Target' => $cfg->{'ENV'}->{'Target'},
			'$Environment' => $cfg->{'ENV'}->{'Environment'},
			'$ConfigFile' => $cfgFile,
			'$ProjectName' => $outPrefix,
			'$email' => $email,
			'@AllSamples' => &getSamples($data->{$ProjectType}),
	);
	eval($cfg->{'Perl'}) if ($cfg->{'Perl'});
	my $funSrc = &defFunction($cfg->{'Function'}) if ($cfg->{'Function'});
	eval($funSrc);
	foreach my $patientID (keys %{$data->{$ProjectType}}) {
		$value{'$patientID'} = $patientID;
		&addTasks($cfg,$data->{$ProjectType}->{$patientID},\%value);
	}
}


#Processing Done Flag
my (@order, %orders, %DoneFlag);
foreach my $t (@Tasks) {
	$DoneFlag{$t->{'Name'}} = $t->{'DoneFlag'};
	next unless ($t->{'Order'});
	my @ord = grep {$_} (split /\n/, $t->{'Order'});
	push(@order, @ord);
	foreach my $d (@ord) {
		warn "Order ERROR: $d" unless ($d =~ /order\s*(\S+)\s*before\s*(\S+)/);
		my ($t1,$t2) = ($1,$2);
		push(@{$orders{$t2}}, $t1);
	}
}
foreach my $id (keys %DoneFlag) {
	next unless ($DoneFlag{$id});
	&SetFlagDone($id);
}
#Output Tasks
my @shellStr;
open OUT,">$outDir/Tasks/$outPrefix/$outPrefix.Tasks" or die $!;
foreach my $t (@Tasks) {
	print OUT "job_begin\n";
	print OUT "\tname $t->{'Name'}\n";
	print OUT "\tmemory $t->{'Mem'}\n";
	print OUT "\tcpu $t->{'CPU'}\n" if ($t->{'CPU'});
	print OUT "\tqueue $t->{'Queue'}\n" if ($t->{'Queue'});
	print OUT "\thost $t->{'host'}\n" if ($t->{'host'});
	print OUT "\tproject $t->{'Project'}\n" if ($t->{'Project'});
	if ($t->{'Directory'}) {
		make_path($t->{'Directory'}, {verbose => 1, mode => 0755});
		print OUT "\tdirectory $t->{'Directory'}\n";
	}
	if ($DoneFlag{$t->{'Name'}} == 1) {
		print OUT "\tstatus done\n\tid 12345678\n\tcpu_usage 0\n\twallclock 0\n\tmemory_usage 12345678\n\tswap_usage 0\n";
	}
	print OUT "\tcmd_begin\n";
	my $cmd = "";
	foreach my $c (split /\n/,$t->{'Command'}) {
		next unless ($c);
		next if ($c =~ /^#/);
		print OUT "\t\t$c;\n";
		$cmd .= "$c\n";
	}
	print OUT "\tcmd_end\n";
	push(@shellStr, [$t->{'Name'}, $cmd, $t->{'Directory'}]);
	print OUT "job_end\n";
}
foreach my $c (@order) {
	print OUT "$c\n";
}
print OUT "log_dir $outDir/Tasks/$outPrefix/log\n";
close OUT;
if ($opt{'sh'}) {
	make_path("$outDir/Tasks/$outPrefix/bin", {verbose => 1, mode => 0755});
	open SH,">$outDir/Tasks/$outPrefix/bin/$outPrefix.sh" or die $!;
	foreach my $sh (@shellStr) {
		my $file = "$outDir/Tasks/$outPrefix/bin/" . $sh->[0] . ".sh";
		open TSK,">$file" or die $!;
		print TSK $sh->[1];
		close TSK;
		print SH "sh $file\n";
		if ($sh->[0] =~ /Report_.*\.sh/ and $sh->[2]) {
			symlink($file, "$sh->[2]/$sh->[0].sh") or warn "Symlink $file ERROR!";
		}
	}
	close SH;
}
exit(0) if ($opt{'inexe'});

&runTask("$outDir/Tasks/$outPrefix/$outPrefix.Tasks", 2);

############################ Functions ####################################
sub waitForData {
	my $data = shift @_;
	my @files;
	foreach my $ProjectType (keys %{$data}) {
		foreach my $patientID (keys %{$data->{$ProjectType}}) {
			foreach my $d (@{$data->{$ProjectType}->{$patientID}}) {
				$d->[3] = &getRealPath($d->[3], $d->[1], $d->[2]) if ($d->[3] =~ /\*/);
				push(@files, "$d->[3]/$d->[1]/$d->[1]_$d->[2]_1.adapter.list.gz", "$d->[3]/$d->[1]/$d->[1]_$d->[2]_2.adapter.list.gz");
			}
		}
	}
	while (1) {
		last if (&Ready(\@files));
		sleep(300);
	}
	return 1;
}

sub getRealPath {
	my ($dir,$libID,$laneID) = @_;
	while (1) {
		chomp(my $file = `ls $dir/$libID/${libID}_${laneID}_1.fq.gz 2>/dev/null`);
		if ($file) {
			$dir = substr($file, 0, length($file) - length("/$libID/${libID}_${laneID}_1.fq.gz"));
			return $dir;
		}
		sleep(300);
	}
}


sub Ready {
	for(my $i = 0; $i < @{$_[0]}; $i++) {
		return 1 if (@{$_[0]} < 1);
		my $f = $_[0]->[$i];
		return 0 unless ($f and -e $f);
		chomp(my $test = `gzip -t $f 2>&1`);
		if ($test =~ /gzip:/s) {
			return 0;
		} else {
			splice(@{$_[0]}, $i, 1);
			redo;
		}
	}
	return 1;
}

sub getSamples {
	my %hash;
	foreach my $p (sort keys %{$_[0]}) {
		foreach my $line (@{$_[0]->{$p}}) {
			$hash{$line->[0]}++;
		}
	}
	return [sort keys %hash];
}

sub addTasks {
	my ($cfg,$data,$valueRef) = @_;
	my %dataHash;
	foreach my $l (@$data) {
		$dataHash{$l->[0]}->{$l->[1]}->{$l->[2]}++;
	}
	foreach my $t (@{$cfg->{'Task'}}) {
		foreach my $l (@$data) {
			$valueRef->{'$SampleID'} = $l->[0],
			$valueRef->{'$LibID'} = $l->[1],
			$valueRef->{'$LaneID'} = $l->[2],
			$valueRef->{'$RawDataDir'} = $l->[3],
			$valueRef->{'@LaneID'} = [ (keys %{$dataHash{$l->[0]}->{$l->[1]}}) ],
			$valueRef->{'@LibID'} = [ (keys %{$dataHash{$l->[0]}}) ],
			$valueRef->{'$cancerType'} = $info->{$l->[0]}->{'检测项目'},
			$valueRef->{'$disease'} = $info->{$l->[0]}->{'疾病种类'},
			$valueRef->{'$patientName'} = $info->{$l->[0]}->{'姓名'},
			$valueRef->{'$DoneFlag'} = ($info->{$l->[0]}->{'DoneFlag'}) ? $info->{$l->[0]}->{'DoneFlag'} : 0,
			$valueRef->{'$cancerType'} =~ s/\(.*\)//g;
			$valueRef->{'$cancerType'} =~ s/（.*）//g;
			$valueRef->{'$disease'} =~ s/\(.*\)//g;
			$valueRef->{'$disease'} =~ s/（.*）//g;
			eval($t->{'Perl'}) if ($t->{'Perl'});
			my $task = &replaceVar($t, $valueRef);
			push(@Tasks, $task) unless (exists $taskHash{$task->{'Name'}});
			$taskHash{$task->{'Name'}}++;
		}
	}
	my %compare;
	foreach my $s (keys %dataHash) {
		next unless ($info->{$s}->{'比较'});
		next if (exists $compare{$info->{$s}->{'比较'}});
		eval($info->{$s}->{'比较'});
		$compare{$info->{$s}->{'比较'}}++;
	}
}

sub defFunction {
	my @functions = @{$_[0]};
	my $source = "";
	for(my $i = 0; $i < @functions; $i++) {
		my $fun = $functions[$i];
		my $TaskStr = '1' x scalar(@{$fun->{'Task'}});
		my $code = "sub $fun->{'Id'} {\n";
		$code .= "\tmy \$TaskStr = $TaskStr;\n";
		$code .= "\t$fun->{'Perl'}\n" if ($fun->{'Perl'});
		$code .= "\tfor(my \$j = 0; \$j < \@{\$cfg->{\'Function\'}->[$i]->{\'Task\'}}; \$j++) {\n";
		$code .= "\t\tnext unless (substr(\$TaskStr, \$j, 1) == 1);\n";
		$code .= "\t\tmy \$task = &replaceVar(\$cfg->{\'Function\'}->[$i]->{\'Task\'}->[\$j], \\%value);\n";
		$code .= "\t\tpush(\@Tasks, \$task) unless (exists \$taskHash{\$task->{\'Name\'}});\n";
		$code .= "\t\t\$taskHash{\$task->{\'Name\'}}++;\n";
		$code .= "\t}\n";
		$code .= "\treturn $fun->{'Return'};\n" if ($fun->{'Return'});
		$code .= "}\n";
		$source .= $code;
	}
	return $source;
}

sub replaceVar {
	my %task = %{$_[0]};
	my %hash = %{$_[1]};
	foreach my $t (keys %task) {
		my @lines = split /\n/,$task{$t};
		foreach my $line (@lines) {
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			#$line =~ s/^#.*//;
			while ($line =~ /(\$[^_'"\[\]\{\}\/\.\s]+)/g) {
				next unless (exists $hash{$1});
				&replaceAll($line, $1, $hash{$1});
			}
			if ($line =~ /@\[([^_\[\]\{\}\/\.\s]+)\]/ and exists $hash{"\@$1"}) {
				my $orig = "$&";
				my $vKey = "\@$1";
				my @result;
				foreach my $v (@{$hash{$vKey}}) {
					my $d = $line;
					&replaceAll($d, $orig, $v);
					push(@result,$d);
				}
				$line = join("\n",@result);
			}
			while ($line =~ /@\{([^\}]+)\}/g) {
				my $orig = "$&";
				my $content = $1;
				my @result;
				next unless ($content =~ /(@[^_\[\]\{\}\/\.\s]+)/ and exists $hash{"$1"});
				my $key = "$1";
				foreach my $v (@{$hash{$key}}) {
					my $d = $content;
					&replaceAll($d, $key, $v);
					push(@result,$d);
				}
				my $total = join(" ", @result);
				&replaceAll($line, $orig, $total);
			}
			while ($line =~ /(\@[^_\[\]\{\}\/\.\s]+)/g) {
				my $m = "$1";
				next unless (exists $hash{$m});
				my $result = scalar(@{$hash{$m}});
				&replaceAll($line, $m, $result);
			}
		}
		@lines = split /\n/,(join("\n", @lines));
		my @NewLine;
		foreach my $line (@lines) {
			if ($line =~ /^\[IF ([^\]]+)\]\s*/) {
				my $condition = $1;
				substr($line, 0, length($&)) = '';
				push(@NewLine, $line) if (&judge($condition));
			} else {
				push(@NewLine, $line) if ($line ne '');
			}
		}
		$task{$t} = join("\n",@NewLine);
	}
	if (exists $task{'DoneFlag'}) {
		$task{'DoneFlag'} = &judge($task{'DoneFlag'});
	} else {
		$task{'DoneFlag'} = 0;
	}
	return \%task;
}

sub replaceAll {
	my ($str,$k,$v) = (\$_[0],\$_[1],\$_[2]);
	print "$$str $$k $$v\n" unless ($$str);
	my $len = length($$k);
	my $num = 0;
	while (1) {
		my $pos = index($$str,$$k);
		last if ($pos == -1);
		substr($$str, $pos, $len) = $$v;
		$num ++;
	}
	return $num;
}

sub judge {
	my $c = shift @_;
	my $result = `perl -e 'if ($c) {print "1";} else {print "0";}'`;
	return $result;
}

sub getProjectType {
	my $string = shift @_;
	if ($string =~ /诺易康专业版/) {
		return "pmp";
	} elsif ($string =~ /诺易康标准版/) {
		return "pms";
	} elsif ($string =~ /Liquid Biopsy/) {
		return "lb";
	} elsif ($string =~ /诺思安/) {
		return "cr";
	} elsif ($string =~ /全外显子测序/) {
		return "ex";
	} else {
		return $string;
		#print STDERR "ERROR! Cannot Judge project type for $string\n";
	}
}

sub LoadingCfgFile {
	my $cfgFile = shift @_;
	my (%data, %info, $email, $phone, $customInfo);
	print STDERR "Loading $cfgFile ...\n";
	my @content;
	open CFG,"<$cfgFile" or die $!;
	$customInfo = "检测产品\t姓名\t检测项目\t样本编号\n";
	#binmode(CFG,':encoding(utf-8)');
	my (%colTitle, %emailHash, %phoneHash);
	while (<CFG>) {
		chomp;
		my @line = split /\t/,$_;
		next if (@line < 5);
		if (%colTitle) {
			my $sampleID = $line[$colTitle{'样本编号'}];
			my $patientID = $line[$colTitle{'身份证号'}];
			my $ProjectType = &getProjectType($line[$colTitle{'检测产品'}]);
			my @manager = grep {$_} split /，/, $line[$colTitle{'信息负责人'}];
			next if (exists $info{$sampleID});
			foreach my $m (@manager) {
				next unless (exists $contacts{$m});
				$emailHash{$contacts{$m}->[0]}++;
				$phoneHash{$contacts{$m}->[1]}++;
			}
			my @paths = grep {$_} split /;/,$line[$colTitle{'数据路径'}];
			foreach my $p (@paths) {
				next unless ($p =~ /(\S+)\{(\S+)\}/);
				my ($pathStr, $libStr) = ($1, $2);
				while ($libStr =~ /([^\s,\(]+)\(([^\s\(\)]+)\)/g) {
					my $libID = $1;
					my $laneStr = $2;
					#print "$libID $laneStr\n";
					my @lane = split /,/,$laneStr;
					foreach my $d (@lane) {
						push(@{$data{$ProjectType}->{$patientID}}, [$sampleID, $libID, $d, $pathStr]);
					}
				}
			}
			my %infoLine;
			foreach my $k (keys %colTitle) {
				$infoLine{$k} = $line[$colTitle{$k}];
			}
			$info{$sampleID} = {%infoLine};
			$customInfo .= join("\t", $line[$colTitle{'检测产品'}], $line[$colTitle{'姓名'}], $line[$colTitle{'检测项目'}],$line[$colTitle{'样本编号'}]) . "\n";
		} else {
			for (my $i = 0; $i < @line; $i++) {
				$colTitle{$line[$i]} = $i;
			}
		}
	}
	close CFG;
	$email = join(",", (sort {$emailHash{$b} <=> $emailHash{$a}} keys %emailHash));
	$phone = join(",", (sort {$phoneHash{$b} <=> $phoneHash{$a}} keys %phoneHash));
	print STDERR "Done.\n";
	return (\%data, \%info, $email, $phone, $customInfo);
}

sub getRealDir {
	my $result = shift @_;
	$result =~ s/\/$//;
	if ($result !~ /^\//) {
		chomp(my $cwd = `pwd`);
		$result = "$cwd/$result";
	}
	return $result;
}

sub getBasename {
	my $name = shift @_;
	$name = (split /\//,$name)[-1];
	$name = (split /[\.]/,$name)[0];
	return $name;
}

sub LoadingContacts {
	my $file = shift @_;
	return () unless ($file and -e $file);
	my %hash;
	open CTS,"<$file" or die $!;
	while (<CTS>) {
		chomp;
		my @line = split;
		next if (@line < 3);
		$hash{$line[0]} = [@line[1,2]];
	}
	close CTS;
	return %hash;
}

sub runTask {
	my ($taskFile,$maxt) = @_;
	my $basename = (split /\//,$taskFile)[-1];
	system "cp $taskFile $taskFile.1";
	chomp(my $date = `date`);
	for (my $i = 1; $i <= $maxt; $i++) {
		if ($i == 1) {
			&sendmail('cancerPipeline@novogene.cn', $email, "开始运行任务${basename}，请3小时后看结果", "你的任务${basename}已于${date}开始运行，请3小时后查看结果。\n任务文件路径：$taskFile.$i\n\n客户信息如下所示：\n$customInfo\n");
		}
		system "$RealBin/Bin/sjm $taskFile.$i";
		&waitCmdDone("$RealBin/Bin/sjm $taskFile.$i");
		my ($success, $message) = &AnalysisLog("$taskFile.$i.status.log");
		chomp($date = `date`);
		if ($success) {
			&sendmail('cancerPipeline@novogene.cn', $email, "成功完成任务$basename", "你的任务${basename}已于${date}成功完成。\n任务文件路径：$taskFile.$i\n日志文件路径：$taskFile.$i.status.log\n工作目录：$outDir\n\n任务统计信息如下所示：$message\n", "$taskFile.$i.status.log");
			last;
		} else {
			my ($subject, $msg);
			if ($i == $maxt) {
				$subject = "任务失败：${basename}，请手动检查并重跑";
				$msg = "任务运行失败${basename}，这是第${i}次出错！请你检查任务文件并重新运行以下命令:\n$RealBin/Bin/sjm $taskFile.$i\n任务文件路径：$taskFile.$i\n日志文件路径：$taskFile.$i.status.log\n工作目录：$outDir\n\n任务统计信息如下所示：$message\n";
			} else {
				$subject = "任务第${i}次出错：${basename}，系统会自动重投。";
				$msg = "警告：你的任务${basename}已经第${i}次出错！系统会自动重投，失败可能是由于集群环境或任务文件配置不当，请手动检查任务文件。\n任务文件路径：$taskFile.$i\n日志文件路径：$taskFile.$i.status.log\n工作目录：$outDir\n\n任务统计信息如下所示：$message\n";
				my $d = $i + 1;
				system "cp $taskFile.$i.status $taskFile.$d";
			}
			&sendmail('cancerPipeline@novogene.cn', $email, $subject, $msg, "$taskFile.$i.status.log");
		}
	}
}

sub AnalysisLog {
	my $logFile = shift @_;
	my ($success, $message) = (1, "");
	return (0, "Cannot find log File $logFile") unless (-e $logFile);
	my $flag = 0;
	open LOG,"<$logFile" or die $!;
	while (<LOG>) {
		$flag = 1 if (/Successful jobs:/ or /Failed jobs:/ or /Incomplete jobs:/);
		$success = 0 if (/Failed jobs:/ or /Incomplete jobs:/);
		$message .= $_ if ($flag);
	}
	close LOG;
	return ($success, $message);
}

sub waitCmdDone {
	my $cmd = shift @_;
	my $flag = 1;
	while ($flag) {
		my $t = new Proc::ProcessTable;
		$flag = 0;
		foreach my $p (@{$t->table}) {
			$flag ++ if ($p->cmndline eq $cmd);
		}
		sleep(60);
	}
	return 1;
}

sub SetFlagDone {
	my $id = shift @_;
	$DoneFlag{$id} = 1;
	if (exists $orders{$id}) {
		foreach my $d (@{$orders{$id}}) {
			&SetFlagDone($d);
		}
	}
	return 0;
}

sub sendmail {
	my $from = shift @_;
	my $to = shift @_;
	my $subject = shift @_;
	my $body = shift @_;
	my @attachment = @_;
	my $message = MIME::Lite->new(
		From => $from,
		To => $to,
		Subject => $subject,
		Type => 'multipart/mixed',
	);
	$message->attach(
		Type => 'text/plain;charset=utf-8',
		Data => $body,
	);
	foreach my $t (@attachment) {
		next unless ($t and -e $t);
		print "$t\n";
		my $basename = (split /\//,$t)[-1];
		$message->attach(
			Type => 'AUTO',
			Path => $t,
			Filename => $basename,
			Disposition => 'attachment',
		);
	}
	$message->attr('content-type.charset' => 'UTF-8');
	$message->send;
}
