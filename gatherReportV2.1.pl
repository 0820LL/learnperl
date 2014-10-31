#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;
use File::Path qw(make_path);
use File::Basename;
use File::Copy;
use Number::Format qw(:subs :vars);
use FindBin qw($RealBin);
use Statistics::Descriptive;
use XML::Simple qw(:strict);
use Cwd;
use constant MAX_INT => 2**53;
use utf8;
use Data::Dumper;
my $USAGE = qq{
Name: $0
Function: Generate Inner Report
Usage: $0 
Options:
	-ind	<string>	Input data base directory
	-dat	<string>	Config file for all patients and samples
	-sty	<string>	Project Style, like pms,pmp,lb,cr,ex
	-cfg	<string>	Config file for Inner Report.
	-eml	<string>	Config file for E-mail
	-std	<string>	XML file of Check standard.
	-out	<string>	Output directory
Version:
	v2.0; 2014-08-18; caoyinchuan;caoyinchuan\@novogene.cn
};
my ($inputDir, $dataInfile, $projectStyle, $ReportCfgFile, $MailCfgFile, $StandardXMLFile, $outDir);
GetOptions (
	"ind=s" => \$inputDir,
	"dat=s" => \$dataInfile,
	"sty=s" => \$projectStyle,
	"cfg=s" => \$ReportCfgFile,
	"eml=s" => \$MailCfgFile,
	"std=s" => \$StandardXMLFile,
	"out=s" => \$outDir,
);
die "$USAGE" unless ($inputDir and $dataInfile and $projectStyle and ($ReportCfgFile or $MailCfgFile) and $StandardXMLFile and $outDir);
my $data = &LoadingDataCfg($dataInfile, $projectStyle);
my $standard = XMLin($StandardXMLFile, KeyAttr => {}, ForceArray => ['Task'], SuppressEmpty => undef);
$standard = &prepareCfg($standard);
make_path($outDir, {verbose => 1, mode => 0755});
if (-e $ReportCfgFile) {
	my $report = XMLin($ReportCfgFile, KeyAttr => {}, ForceArray => ['Section', 'Body'], SuppressEmpty => undef);
	system("cp -rf $RealBin/src $outDir");
	&outResult("$outDir/index.html", $report, $data);
}
if (-e $MailCfgFile) {
	my $email = XMLin($MailCfgFile, KeyAttr => {}, ForceArray => ['Section', 'Body'], SuppressEmpty => undef);
	&outResult("$outDir/mail.html", $email, $data);
}

sub outResult {
	my ($outFile, $cfg, $data) = @_;
	my ($figID, $tabID) = (1, 1);
	eval(&defFunction('PageHeader', $cfg->{'PageHeader'})) if ($cfg->{'PageHeader'});
	eval(&defFunction('PageFooter', $cfg->{'PageFooter'})) if ($cfg->{'PageFooter'});
	open OUT, ">:encoding(UTF-8)", $outFile or die $!;
	print OUT &replaceVar($cfg->{'Head'}, $data);
	print OUT &Menu($cfg) if ($cfg->{'Menu'});
	print OUT &Catalogue($cfg);
	print OUT &Section($cfg->{'Section'}, $data, 2, "", $figID, $tabID);
	print OUT &replaceVar($cfg->{'Tail'}, $data);
	close OUT;
}

sub Section {
	my ($cfg, $data, $headLevel, $headPrefix) = @_;
	my $figIDRef = \$_[4];
	my $tabIDRef = \$_[5];
	my $result = "";
	return $result unless (@$cfg);
	for (my $i = 0; $i < @{$cfg}; $i++) {
		my $sectionID = ($i + 1);
		my %section = %{$cfg->[$i]};
		$result .= &Text(&replaceVar($section{'TextBefore'}, $data)) if ($section{'TextBefore'});
		if ($section{'NewPage'}) {
			$result .= &PageHeader($section{'ID'});
		} else {
			$result .= "<a name=\"$section{'ID'}\"></a>\n";
		}
		$result .= "<h$headLevel>$headPrefix$sectionID $section{'Title'}</h$headLevel>\n";
		if (exists $section{'Body'}) {
			foreach my $d (@{$section{'Body'}}) {
				$result .= &Text(&replaceVar($d->{'Text'}, $data)) if ($d->{'Text'});
				$result .= &FigList($d->{'FigList'}, $data, $$figIDRef) if ($d->{'FigList'});
				$result .= &Table($d->{'Table'}, $data, $$tabIDRef) if ($d->{'Table'});
			}
		}
		$result .= &Section($section{'Section'}, $data, $headLevel + 1, "$headPrefix$sectionID.", $$figIDRef, $$tabIDRef) if (exists $section{'Section'});
		$result .= &PageFooter() if ($section{'NewPage'});
		$result .= &Text(&replaceVar($section{'TextAfter'}, $data)) if ($section{'TextAfter'});
	}
	return $result;
}

sub FigList {
	my %cfg = %{$_[0]};
	my @data = @{$_[1]};
	my $figIDRef = \$_[2];
	my $result = "";
	$result .= &Text(&replaceVar($cfg{'TextBefore'}, \@data)) if ($cfg{'TextBefore'});
	my $FigFileList = &replaceVar($cfg{'FigFiles'}, \@data);
	my (@Labels, @FigFiles);
	@Labels = grep {$_} (split /\n/, &replaceVar($cfg{'FigLabel'}, \@data)) if ($cfg{'FigLabel'});
	my @FigFileList = &findFiles(grep {$_} (split /\n/, $FigFileList));
	foreach my $s (@FigFileList) {
		$s =~ s/^\s*//g;
		$s =~ s/\s*$//g;
		my $basename = fileparse($s);
		if ($s and -e $s) {
			copy($s, "$outDir/src/images/$basename") or die "Copy file ERROR: $s";
			push(@FigFiles, "src/images/$basename");
		}
	}
	warn "FigFiles Number is Not Equal FigLabels" if (@Labels and @FigFiles != @Labels);
	if (@FigFiles == 1) {
		$result .= "<p class=\"center\">\n<a id=\"example2\" href=\"$Labels[0]\"><img class=\"normal1\" src=\"$FigFiles[0]\" alt=\"example2\"/></a>\n</p>\n";
	} elsif (@FigFiles > 1) {
		$result .= "<p class=\"center\">\n<div class=\"albumSlider\">\n<div class=\"fullview\"><img src='$FigFiles[0]'/></div>\n<div class=\"slider\">\n<div class=\"button movebackward\" title=\"MoveUp\"></div>\n<div class=\"imglistwrap\"><ul class=\"imglist\">\n";
		for (my $i = 0; $i < @FigFiles; $i++) {
			$result .= "<li><a id=\"example2\" href='$FigFiles[$i]' >$Labels[$i]</a></li>\n";
		}
		$result .= "</ul></div>\n<div class=\"button moveforward\" title=\"MoveDown\"></div>\n</div>\n</div>\n</p>\n";
	}
	$result .= "<p class=\"$cfg{'TitleStyle'}\">图$$figIDRef $cfg{'Title'}</p>\n";
	if ($cfg{'Note'}) {
		my @arr = split /\n/,$cfg{'Note'};
		foreach my $s (@arr) {
			next unless ($s);
			$result .= "<p class=\"$cfg{'NoteStyle'}\">$s</p>\n";
		}
	}
	$result .= &Text(&replaceVar($cfg{'TextAfter'}, \@data)) if ($cfg{'TextAfter'});
	$$figIDRef++;
	return $result;
}

sub Table {
	my %cfg = %{$_[0]};
	my @data = @{$_[1]};
	my $tabIDRef = \$_[2];
	my $result = "";
	$result .= &Text(&replaceVar($cfg{'TextBefore'}, \@data)) if ($cfg{'TextBefore'});
	my $content;
	if ($cfg{'Content'}) {
		my @tmp = grep {$_} (split /\n/,$cfg{'Content'});
		my @tmp2;
		foreach my $t (@tmp) {
			$t =~ s/^\s+//;
			$t =~ s/\s+$//;
			next unless ($t);
			push(@tmp2, grep {$_} split /\n/, &replaceVar($t, \@data));
		}
		foreach my $t (@tmp2) {
			push (@$content, [split /\t/,$t]);
		}
	} elsif ($cfg{'TabFile'}) {
		my @TabFiles = grep {$_} split /\n/, &replaceVar($cfg{'TabFile'},\@data);
		$content = &readTabFiles(@TabFiles);
	}
	$content = &addColor($content, $standard->{$data[0]->{'$ProjectType'}}->{$cfg{'Standard'}}) if ($cfg{'Standard'} and $standard->{$data[0]->{'$ProjectType'}}->{$cfg{'Standard'}});
	$result .= &addTable($cfg{'TitleStyle'}, "表$$tabIDRef $cfg{'Title'}", $cfg{'TableStyle'}, $content, $cfg{'TitleFormat'}, $cfg{'NoteStyle'}, $cfg{'Note'});
	$result .= &Text(&replaceVar($cfg{'TextAfter'}, \@data)) if ($cfg{'TextAfter'});
	$$tabIDRef++;
	return $result;
}


sub Menu {
	my %cfg = %{$_[0]};
	my $result = "<div id=\"\" style=\"left:0;top:0;position:fixed;padding-top:0px;height:100%;z-index:99999;\">\n<ul class=\"nav\">\n<li class=\"item\"><a href=\"#\">目 录</a>\n<ul class=\"nav\">\n";
	$result .= &subMenu(\%cfg, '');
	$result .= "</ul>\n</li>\n</ul>\n</div>\n";
	return $result;
}

sub subMenu {
	my %hash = %{$_[0]};
	my $prefix = pop(@_);
	my $string = "";
	return "" unless (exists $hash{'Section'});
	my $idx = 1;
	foreach my $d (@{$hash{'Section'}}) {
		my $id = $d->{'ID'};
		my $title = $d->{'Title'};
		if (exists ${$d}{'Link'}) {
			my $link = $d->{'Link'};
			$string .= "<li class=\"item\"><a href=\"$link\">$prefix$idx $title</a>";
		} else {
			$string .= "<li class=\"item\"><a href=\"#$id\">$prefix$idx $title</a>";
		}
		my $subMenu = &subMenu($d,"$prefix$idx.");
		if ($subMenu) {
			$string .= "\n<ul class=\"nav\">\n$subMenu</ul>\n";
		}
		$string .= "</li>\n";
		$idx++;
	}
	return $string;
}


sub Catalogue {
	my %cfg = %{$_[0]};
	my $sectionID = 1;
	my ($year, $mon, $mday) = &getDate();
	my $ProjectID = $data->[0]->{'$ProjectID'};
        my $ProjectType = $data->[0]->{'$ProjectType'};
	my $result = "";
	if ($cfg{'Catalogue'}) {
		$result = &PageHeader('home') . "<h1>$ProjectID ${ProjectType}检验报告</h1>\n<table align=\"center\">\n<tr><td>项目编号：</td><td>$ProjectID</td></tr>\n<tr><td>日　　期：</td><td>${year}年${mon}月${mday}日</td></tr></table>\n";
		$result .= "<p class=\"paragraph\">\n<ul>\n";
		$result .= &subCatalogue(\%cfg, '');
		$result .= "</ul>\n</p>\n";
		$result .= &PageFooter();
	} else {
		$result = "<a name=\"home\"></a>\n<h1>$ProjectID ${ProjectType}检验报告</h1>\n<table align=\"center\">\n<tr><td>项目编号：</td><td>$ProjectID</td></tr>\n<tr><td>日　　期：</td><td>${year}年${mon}月${mday}日</td></tr></table>\n"
	}
	return $result;
}

sub getDate {
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	return($year, $mon, $mday, $hour, $min, $sec);
}

sub subCatalogue {
	my %hash = %{$_[0]};
	my $prefix = pop(@_);
	my $string = "";
	return "" unless (exists $hash{'Section'});
	my $idx = 1;
	foreach my $d (@{$hash{'Section'}}) {
		my $id = $d->{'ID'};
		my $title = $d->{'Title'};
		if (exists ${$d}{'Link'}) {
			my $link = $d->{'Link'};
			$string .= "<li class=\"item\"><a href=\"$link\">$prefix$idx $title</a>";
		} else {
			$string .= "<li><a href=\"#$id\">$prefix$idx $title</a></li>\n";
		}
		my $subSection = &subCatalogue($d,"$prefix$idx.");
		if ($subSection) {
			$string .= "<ul class=\"alt\">\n$subSection</ul>\n";
		}
		$idx++;
	}
	return $string;
}

sub defFunction {
	my ($name, $code) = @_;
	$code =~ s/"/\\"/g;
	my $result = "
sub $name {
	my \$value = \"\";
	\$value = \$_[0] if (\@_);
	my \$result = &replaceVar(\"$code\", \$value);
	return \$result;
}\n";
	return $result;
}

sub replaceVar {
	my $string = shift @_;
	return $string unless ($string =~ /\$(\w+)/m);
	#print "$string\n" if ($string =~ /\$value/);
	if (ref($_[0]) eq "ARRAY") {
		my @array = @{$_[0]};
		my %hash = ();
		my $result = "";
		foreach my $h (@array) {
			chomp(my $s = $string);
			foreach my $key (keys %{$h}) {
				my $key1 = $key;
				$key1 = "\\\$$1" if ($key1 =~ /\$(\w+)/);
				$s =~ s/\$value\{'$key1'\}/$h->{$key}/mg;
				$s =~ s/\$value\{"$key1"\}/$h->{$key}/mg;
				$s =~ s/$key1/$h->{$key}/mg;
			}
			next if (exists $hash{$s});
			$result .= "$s\n";
			$hash{$s}++;
		}
		return $result;
	} elsif (ref($_[0]) eq "HASH") {
		my %hash = %{$_[0]};
		my $s = $string;
		foreach my $key (keys %hash) {
			my $key1 = $key;
			$key1 = "\\\$$1" if ($key1 =~ /\$(\w+)/);
			$s =~ s/\$value\{'$key1'\}/$hash{$key}/mg;
			$s =~ s/\$value\{"$key1"\}/$hash{$key}/mg;
			$s =~ s/$key1/$hash{$key}/mg;
		}
		return $s;
	} else {
		my $value = $_[0];
		my $s = $string;
		$s =~ s/\$value/$value/mg;
		return $s;
	}
}

sub Text {
	my @array;
	foreach my $d (@_) {
		next unless (defined($d) and $d);
		push(@array, split /\n/,$d);
	}
	my $result = "";
	foreach my $ins (@array) {
		next unless ($ins);
		$result .= "<p class=\"paragraph\">$ins</p>\n";
	}
	return $result;
}

sub LoadingDataCfg {
	my ($cfgFile, $type) = @_;
	my (%hash, @data);
	my $ProjectID = (split /[\._]+/,fileparse($cfgFile))[0];
	open CFG,"<:encoding(UTF-8)", $cfgFile or die $!;
	my %colTitle;
	while (<CFG>) {
		chomp;
		my @line = split /\t/,$_;
		next if (@line < 5);
		if (%colTitle) {
			my $sampleID = $line[$colTitle{'样本编号'}];
			my $patientID = $line[$colTitle{'身份证号'}];
			my $ProjectType = &getProjectType($line[$colTitle{'检测产品'}]);
			next unless ($ProjectType eq $type);
			next if (exists $hash{$sampleID});
			my %infoLine;
			foreach my $k (keys %colTitle) {
				$infoLine{$k} = $line[$colTitle{$k}];
			}
			$infoLine{'$inputDir'} = $inputDir;
			$infoLine{'$OutDir'} = $outDir;
			$infoLine{'$PatientID'} = $infoLine{'身份证号'};
			$infoLine{'$SampleID'} = $infoLine{'样本编号'};
			$infoLine{'$ProjectID'} = $ProjectID;
			$infoLine{'$ProjectType'} = $type;
			my @paths = grep {$_} split /;/,$infoLine{'数据路径'};
			foreach my $p (@paths) {
				next unless ($p =~ /(\S+)\{(\S+)\}/);
				my ($pathStr, $libStr) = ($1, $2);
				while ($libStr =~ /([^\s,\(]+)\(([^\s\(\)]+)\)/g) {
					my $libID = $1;
					my $laneStr = $2;
					my @lane = split /,/,$laneStr;
					foreach my $d (@lane) {
						my %info = %infoLine;
						$info{'$RawDataDir'} = $pathStr;
						$info{'$LibID'} = $libID;
						$info{'$LaneID'} = $d;
						push(@data, {%info});
					}
				}
			}
		} else {
			for (my $i = 0; $i < @line; $i++) {
				$colTitle{$line[$i]} = $i;
			}
		}
	}
	close CFG;
	return [@data];
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
		#print STDERR "ERROR! Cannot Judge project type for $string\n";
		return $string;
	}
}


sub today {
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	#return($year, $mon, $mday, $hour, $min, $sec);
	return "${year}年${mon}月${mday}日";
}

sub readTabFiles {
	my @array;
	my @TabFiles = &findFiles(@_);
	if (@TabFiles > 1) {
		for(my $i = 0; $i < @TabFiles; $i++) {
			open TAB, "<:encoding(UTF-8)",$TabFiles[$i] or die "Read $TabFiles[$i] Error: $!";
			#my $sample = (split /\./, (split /\//,$_[$i])[-1])[0];
			#$array[0]->[0] = "Catelogy" if ($i == 0);
			#$array[0]->[$i+1] = $sample;
			my $id = 0;
			while (<TAB>) {
				chomp;
				my @line = split /\t/,$_;
				next if (@line < 2);
				$array[$id]->[0] = $line[0] if ($i == 0);
				$array[$id]->[$i+1] = $line[1];
				$id++;
			}
			close TAB;
		}
	} else {
		open TAB, "<:encoding(UTF-8)",$TabFiles[0] or die "Read $TabFiles[0] Error: $!";
		while (<TAB>) {
			chomp;
			my @line = split /\t/,$_;
			next if (@line < 2);
			push(@array, [@line]);
		}
		close TAB;
	}
	return [@array];
}

sub findFiles {
	my @array;
	foreach my $f (@_) {
		my @files = `ls $f`;
		chomp foreach (@files);
		push(@array, @files) if (@files);
	}
	return @array;
}

sub FormatNumber {
	my $decimal = 2;
	$decimal = $_[1] if (@_ > 1);
	if ($_[0] =~ /^[+-]?\d+$/) {
		my $product = abs($_[0]) * (10 ** $decimal);
		if ($product > MAX_INT) {
			return $_[0];
		} else {
			return format_number($_[0]);
		}
	} elsif ($_[0] =~ /^[+-]?\d+\.\d*$/) {
		return format_number($_[0],$decimal,1);
	} else {
		return $_[0];
	}
}

sub addTable {
	my ($tabNameClass, $tabName, $tabClass, $content, $TitleFormat, $tabNoteClass, $tabNote) = @_;
	$TitleFormat =~ s/\s+//g;
	my ($rowTitle, $colTitle) = split /,/,$TitleFormat;
	my $result = "<p class=\"$tabNameClass\">$tabName</p>\n<table class=\"$tabClass\" align=\"center\">\n";
	my (%pass,  %span);
	if ($rowTitle > 1) {
		my %temp;
		for(my $i = 0; $i < @$content; $i++) {
			if ($content->[$i]->[0] eq '' and $content->[$i]->[1] ne '') {
				$span{"$i\t0"} = "<th colspan='2'>$content->[$i]->[1]</th>";
				$pass{"$i\t1"} ++;
			} elsif ($content->[$i]->[0] ne '') {
				push(@{$temp{$content->[$i]->[0]}}, $i);
			}
		}
		foreach my $k (keys %temp) {
			next unless (@{$temp{$k}} > 1);
			my $spannum = scalar @{$temp{$k}};
			if ($spannum == $temp{$k}->[-1] - $temp{$k}->[0] + 1) {
				$span{"$temp{$k}->[0]\t0"} = "<th rowspan='$spannum'>$k</th>";
				for (my $d = 1; $d < $spannum; $d++) {
					$pass{"$temp{$k}->[$d]\t0"} ++;
				}
			}
		}
	}
	for (my $i = 0; $i < @$content; $i++) {
		my $line = "<tr>";
		for (my $j = 0; $j < @{$content->[$i]}; $j++) {
			next if (exists $pass{"$i\t$j"});
			if (exists $span{"$i\t$j"}) {
				$line .= $span{"$i\t$j"};
			} elsif ($i < $colTitle or $j < $rowTitle) {
				$line .= "<th>$content->[$i]->[$j]</th>";
			} else {
				my $element = $content->[$i]->[$j];
				if ($element =~ /<ERROR>/) {
					$element =~ s/<ERROR>//;
					$element = "<font color=red>" . &FormatNumber($element, 2) . "</font>";
				} elsif ($element =~ /<WARNING>/) {
					$element =~ s/<WARNING>//;
					$element = "<font color=blue>" . &FormatNumber($element, 2) . "</font>";
				} else {
					$element = &FormatNumber($element, 2);
				}
				$line .= "<td>$element</td>";
			}
		}
		$line .= "</tr>\n";
		$result .= $line;
	}
	$result .= "</table>\n";
	if ($tabNote) {
		my @arr = split /\n/,$tabNote;
		$result .= "<p class=\"$tabNoteClass\">\n";
		foreach my $s (@arr) {
			next unless ($s);
			$result .= "$s<br />\n";
		}
		$result .= "</p>\n";
	}
	return $result;
}

sub prepareCfg {
	my $cfg = $_[0];
	foreach my $k (keys %{$cfg}) {
		next if ($k eq "Common");
		foreach my $k1 (keys %{$cfg->{'Common'}}) {
			foreach my $k2 (keys %{$cfg->{'Common'}->{$k1}}) {
				next if ($cfg->{$k}->{$k1}->{$k2});
				$cfg->{$k}->{$k1}->{$k2} = $cfg->{'Common'}->{$k1}->{$k2};
			}
		}
	}
	return $cfg;
}

sub addColor {
	my ($data, $cfg) = @_;
	my (%hash, @standard);
	foreach my $k (keys %{$cfg}) {
		my @array = split /,/,$cfg->{$k};
		my $c = shift @array;
		my @d = split /;/,$c;
		foreach my $e (@d) {
			next unless (defined $e);
			next if ($e eq '');
			$hash{$e} = [@array];
			$standard[$e] = join(",", @array);
		}
	}
	$standard[0] = "Standard" unless (defined $standard[0]);
	my $flag = 0;
	for (my $i = 0; $i < @{$data}; $i++) {
		for (my $j = 0; $j < @{$data->[$i]}; $j++) {
			if (exists $hash{$i} and $j > 0) {
				$flag = 1;
				$data->[$i]->[$j] = &setWarning($data->[$i]->[$j], $hash{$i});
			} elsif (exists $hash{"0$j"} and $i > 0) {
				$flag = 2;
				$data->[$i]->[$j] = &setWarning($data->[$i]->[$j], $hash{"0$j"});
			}
		}
	}
	if ($flag == 1) {
		for (my $i = 0; $i < @{$data}; $i++) {
			my $value = defined($standard[$i]) ? $standard[$i] : "UNSET";
			splice(@{$data->[$i]}, 1, 0, $value);
		}
	} elsif ($flag == 2) {
		splice(@{$data}, 1, 0, []);
		for (my $j = 0; $j < @{$data->[0]}; $j++) {
			my $value = defined($standard[$j]) ? $standard[$j] : "UNSET";
			$data->[1]->[$j] = $value;
		}
	}
	return $data;
}

sub setWarning {
	my $data = shift @_;
	my @standard = @{$_[0]};
	if ($standard[0] eq "+") {
		if ($data <= $standard[1]) {
			return $data;
		} elsif ($data > $standard[2]) {
			return "<ERROR>$data";
		} else {
			return "<WARNING>$data";
		}
	} elsif ($standard[0] eq "-") {
		if ($data >= $standard[1]) {
			return $data;
		} elsif ($data < $standard[2]) {
			return "<ERROR>$data";
		} else {
			return "<WARNING>$data";
		}
	} else {
		warn "Program Config XML file error!";
	}
	return $data;
}
