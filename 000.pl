#!perl -w
###
#Usage:$perl to_find_GGGCGG_TATAAA_140316.pl
###

use strict;

sub GET_GENOME{ #the input data is the s288c genome sequecne
	my $genome="";
	my $genome_file = $_[0];
	open(S288C, $genome_file) || die "$!";
	while(<S288C>){
		chomp;
		if($_!~/^>/){
			$genome = $genome.$_;
		}
	}
	return $genome;
}

sub FIND_MOTIF{ #the input data is s288c geneome, motif01, motif02 and max interval
	my($genome, $motif_for, $motif_back, $max_interval) = ($_[0], $_[1], $_[2], $_[3]);
	my $len_motif_for = length($motif_for);
	my $len_motif_back = length($motif_back);
	my $pos01 = 0;
	while(1){
		my $i = index($genome, $motif_for, $pos01);
		last if($i eq -1);
		my $subgenome = substr($genome, $i+$len_motif_for, $max_interval+$len_motif_back);
		my $pos02 = 0;
		while(1){
			my $j = index($subgenome, $motif_back, $pos02);
			last if($j eq -1);
			my $start = &MAX($i-100,0);
			my $length = $i+$len_motif_for+$j+$len_motif_back+100-$start;
			my $seq = substr($genome,$start,$length);
			print ">$motif_for\_$motif_back\_$start\n";
			print $seq,"\n";
			$pos02 = $j+1;
		}
		$pos01 = $i+1;
	}
}

sub SEQ_RC{ #get the reverse complement sequence.
	my @seq_rc;
	my @seq=split(//,$_[0]);
	foreach my $base (@seq){
		if($base eq "A"){
			unshift(@seq_rc,"T");
		}
		elsif($base eq "T"){
			unshift(@seq_rc,"A");
		}
		elsif($base eq "C"){
			unshift(@seq_rc,"G");
		}
		elsif($base eq "G"){
			unshift(@seq_rc,"C");
		}
		else{
			exit(1);
		}
	}
	return join("",@seq_rc);
}

sub SEQ_COMP{ #get the complement sequence.
	my @seq_comp;
	my @seq = split(//,$_[0]);
	foreach my $base (@seq){
		if ($base eq "A"){
			push(@seq_comp,"T");
		}
		elsif ($base eq "C"){
			push(@seq_comp,"G");
		}
		elsif ($base eq "G"){
			push(@seq_comp,"C");
		}
		elsif ($base eq "T"){
			push(@seq_comp,"A");
		}
		else{
			exit(1);
		}
	}
	return join("",@seq_comp);
}

sub SEQ_REVE{ #get the reverse sequence.
	my @seq_reve;
	my @seq = split(//,$_[0]);
	foreach my $base (@seq){
		unshift(@seq_reve,$base);
	}
	return join("",@seq_reve);
}

sub MAX{
	if($_[0] gt $_[1]){
		return $_[0];
	}else{
		return $_[1];
	}
}

sub MAIN{
	my ($genome_file,$motif01,$motif02,$max_interval )= ("s288c_all_genome_sequence.fasta","GGGCGG","TATAAA",40);
	my $motif01_rc = &SEQ_RC($motif01);
	my $motif02_rc = &SEQ_RC($motif02);
	my $motif01_comp = &SEQ_COMP($motif01);
	my $motif02_comp = &SEQ_COMP($motif02);
	my $motif01_reve = &SEQ_REVE($motif01);
	my $motif02_reve = &SEQ_REVE($motif02);
	my $genome = &GET_GENOME($genome_file);
	&FIND_MOTIF($genome, $motif01, $motif02, $max_interval); # GGGCGG......TATAAA
	&FIND_MOTIF($genome,$motif02_rc,$motif01_rc,$max_interval); # TTTATA......CCGCCC
	&FIND_MOTIF($genome,$motif01_comp,$motif02_comp,$max_interval); # CCCGCC......ATATTT
	&FIND_MOTIF($genome,$motif02_reve,$motif01_reve,$max_interval); #AAATAT......GGCGGG
	return 1;
}

exit(0) if(&MAIN()); #main()入口
