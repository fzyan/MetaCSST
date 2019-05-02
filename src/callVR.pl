#!/usr/bin/perl -w
use strict;

###############################################################################################
##Package: Metagenomic Complex Sequence Scanning Tool (MetaCSST)                             ##
##Developer: Fazhe Yan                                                                       ##
##Email: fazheyan33@163.com # ccwei@sjtu.edu                                                 ##
##Department: Department of Bioinformatics and Biostatistics, Shanghai Jiao Tong University  ##
###############################################################################################


#This script is used to search VRs in the input genomes or assemblies, according to the given raw GTF file generated by the program MetaCCSTmain

my ($predict,$ref,$out)= @ARGV;
die "Error with arguments!\nusage: $0 <Raw GTF File generated by MetaCSSTmain> <Ref genome in FASTA format> <OUT File>\n" if (@ARGV<3);

my ($NAratio,$miss,$LEN,$identity) = (0.5,3,30,0.6);
##default: $NAratio=0.5 (In TR sequence, at least half of the bases are T/C/G)
##default: $miss=3 (At most three Non-A-to-N substitutions)
##default: $LEN=30 (Minimal VR length: 30bp)
##default: $identity=0.6 (Identity shreshold between TR and VR: 60%)

open(OUT,">$out")||die("Error with writing to $out\n");
open(REF,$ref)||die("Error with opening $ref\n");

my %genome = ();
my ($name,$sequence) = ("","");
while(<REF>){
    chomp();
    if($_ =~ />([^\s]+)/){$name = $1;}
    elsif($_ =~ /[^\s]/){
	$sequence = $_;
	if(not exists($genome{$name})){$genome{$name} = $sequence;}
    }
    next;
}

my ($id,$seq,$start,$end,$dgr,$pair,$score,$len,$tmp) = ("","",0,0,"",0,0,0,"");
my @sub_seq=();
my @sub_start=();
my @sub_end=();
my @sub_string=();
my @type=();

my $miss_half = int($miss/2);

open(FILE,$predict)||die("Error with opening $predict\n");
while(<FILE>){
    chomp();
    if($_ =~ /TR/){
	my @data = split(/\s+/,$_);
	push(@sub_seq,$data[6]);
	push(@sub_start,$data[4]);
	push(@sub_end,$data[5]);
	push(@sub_string,$data[3]);
	push(@type,1);
    }
    elsif($_ =~ /VR/){
        my @data = split(/\s+/,$_);
	push(@sub_seq,$data[6]);
        push(@sub_start,$data[4]);
        push(@sub_end,$data[5]);
	push(@sub_string,$data[3]);
        push(@type,2);
    }
    elsif($_ =~ /RT/){
        my @data = split(/\s+/,$_);
	push(@sub_seq,$data[6]);
        push(@sub_start,$data[4]);
        push(@sub_end,$data[5]);
	push(@sub_string,$data[3]);
        push(@type,3);
    }
    elsif($_ =~ /DGR/){
	my @data = split(/\s+/,$_);
	($start,$end,$score) = ($data[4],$data[5],$data[2]);
	$id = $data[0];
	$len = $end-$start+1;
	if(exists($genome{$id})){
	    $seq = $genome{$id};
	    if($seq ne ""){
		my $index = 0;
		for(my $i=0;$i<@sub_seq;$i++){
		    if($type[$i] == 1){
			my ($start_new,$end_new) = (-1,-1);
			my $tmp_sub = "";
			
			my $NA = int(length($sub_seq[$i])*$NAratio);
			
			if(numNA($sub_seq[$i]) >= $NA){
			    my $quarter = int(($sub_end[$i]-$sub_start[$i])/4) + $sub_start[$i];
			    my $middle = int(($sub_end[$i]-$sub_start[$i])/4)*2 + $sub_start[$i];
			    my $quarter3 = int(($sub_end[$i]-$sub_start[$i])/4)*3 + $sub_start[$i];
			    
			    if($sub_string[$i] eq '+'){
				my $seq_left = substr($seq,$sub_start[$i],$middle-$sub_start[$i]+1);
				my $seq_middle = substr($seq,$quarter,$quarter3-$quarter+1);
				my $seq_right = substr($seq,$middle,$sub_end[$i]-$middle+1);
				($tmp_sub,$index,$start_new,$end_new)=searchVR($sub_seq[$i],$sub_start[$i],$sub_end[$i],$seq,$miss,$sub_string[$i],$id,$identity);
				if($index == 0){
				    ($tmp_sub,$index,$start_new,$end_new)=searchVR($seq_right,$middle,$sub_end[$i],$seq,$miss_half,$sub_string[$i],$id,$identity);
				    if($index == 0){
					($tmp_sub,$index,$start_new,$end_new)=searchVR($seq_middle,$quarter,$quarter3,$seq,$miss_half,$sub_string[$i],$id,$identity);
					if($index == 0){
					    ($tmp_sub,$index,$start_new,$end_new)=searchVR($seq_left,$sub_start[$i],$middle,$seq,$miss_half,$sub_string[$i],$id,$identity);
					}
				    }
				}
			    }
			    else{
				my $seq_left = myReverse(substr($seq,$middle,$sub_end[$i]-$middle+1));
				my $seq_middle = myReverse(substr($seq,$quarter,$quarter3-$quarter+1));
				my $seq_right = myReverse(substr($seq,$sub_start[$i],$middle-$sub_start[$i]+1));
				
				($tmp_sub,$index,$start_new,$end_new)=searchVR($sub_seq[$i],$sub_start[$i],$sub_end[$i],$seq,$miss,$sub_string[$i],$id,$identity);
				if($index == 0){
				    ($tmp_sub,$index,$start_new,$end_new)=searchVR($seq_right,$sub_start[$i],$middle,$seq,$miss_half,$sub_string[$i],$id,$identity);
				    if($index == 0){
					($tmp_sub,$index,$start_new,$end_new)=searchVR($seq_middle,$quarter,$quarter3,$seq,$miss_half,$sub_string[$i],$id,$identity);
					if($index == 0){
					    ($tmp_sub,$index,$start_new,$end_new)=searchVR($seq_left,$middle,$sub_end[$i],$seq,$miss_half,$sub_string[$i],$id,$identity);
					}
				    }
				}
			    }
			    
			}
			$tmp .= $tmp_sub;
			$pair += $index;
			if($start_new != -1 && $start_new < $start){
			    $start = $start_new;
			}
			if($end_new > $end){$end=$end_new;}
			
		    }   
		}
		
		if($pair != 0){
		    print OUT "$tmp";		    
		    for(my $i=0;$i<@sub_seq;$i++){
			if($type[$i] == 3){
			    print OUT "$id\tRT\t$sub_string[$i]\t$sub_start[$i]\t$sub_end[$i]\t$sub_seq[$i]\n";
			}
		    }
		    
		    my $len = length($dgr);
		}
		my $integrity = "incomplete";
		my $expand = $end-$start+1;
		if($pair != 0){$integrity = "complete";}
	    }
	}    
	($id,$seq,$start,$end,$dgr,$pair,$score,$len,$tmp) = ("","",0,0,"",0,0,0,"");
	@sub_seq=();
	@sub_start=();
	@sub_end=();
	@sub_string=();
	@type=();
    
    }
    next;
}
close FILE;

sub searchVR{
    my ($TR,$start,$end,$seq,$miss,$string,$id,$identity)=@_;

    my $start_init = $start; #init start position of TR
    my $end_init = $end; #intit end position of TR

    my $tmp="";
    my $len = length($TR);

    my($result,$total_start,$total_end)=(0,$start,$end);

    my $seq2="";
    if($string eq '+'){
	$seq2=$seq;
    }
    else{
	$seq2 = myReverse($seq);
	my $num_tmp = $start;
	$start = length($seq2)-1-$end;
        $end = length($seq2)-1-$num_tmp;
    }
    
#search for positive string
    for(my $i=0;$i<length($seq)-length($TR);$i++){
	if($i+length($TR)-1 < $start_init || $i > $end_init){
	    # TR and VR are not allowed to overlap in the position, regardless of the direction
	    my $index = 0;
	    my $substr = substr($seq,$i,length($TR));
	    
	    my $error = 0;
	    my $mut = 0;
	    
	    my $mutation = "";

	    for(my $j=0;$j<$len;$j++){
		my $char1 = substr($TR,$j,1);
		my $char2 = substr($substr,$j,1);
		if($char1 eq 'A' && $char1 ne $char2){
		    $mut++;
		}
		
		elsif($char1 ne 'A' && $char1 ne $char2 ){
		    $mutation .= "$char1-$char2;";
		    $error += 1;
		    if($error > $miss){
			$index = 1;
			last;
		    }
		}
	    }
	    
	    if($index == 0){ ## a VR founded,then extention is carried on 
		if($mutation ne ""){
		 ;#   print "mutation:$mutation\n";
		}
		my ($left,$right)=(1,1);
		for($left=1;$i-$left >= 0 && $start-$left >= 0;$left++){
		    my $char1 = substr($seq2,$start-$left,1); #TR
		    my $char2 = substr($seq,$i-$left,1); #VR
		    if($char1 eq 'A' && $char1 ne $char2){
			$mut++;
		    }
		    elsif($char1 ne 'A' && $char1 ne $char2){
			last;
		    }
		}
		for($right=1;$i+$len-1+$right < length($seq) && $end+$right < length($seq);$right++){
                    my $char1 = substr($seq2,$end+$right,1);
                    my $char2 = substr($seq,$i+$len-1+$right,1);
		    if($char1 eq 'A' && $char1 ne $char2){
                        $mut++;
                    }
                    elsif($char1 ne 'A' && $char1 ne $char2){
                        last;
                    }
                }
		$left -= 1;
		$right -= 1;
		
		my ($a,$b,$c,$d)=($start-$left,$end+$right,$i-$left,$i+$len-1+$right);
		my $TR_new = substr($seq2,$a,$b-$a+1);
                my $VR_new = substr($seq,$c,$d-$c+1);
		
		if($string eq '-'){
		    my $num_tmp = $a;
                    $a = length($seq2)-1-$b;
                    $b = length($seq2)-1-$num_tmp;
                }

		if(length($TR_new) == length($VR_new) && length($TR_new) >= $LEN && reCheck($TR_new,$VR_new,$mut,$error,$identity) == 0){
		    # a TR-VR pair found, check the length, substitution number and identity
		    $tmp .= "$id\tTR\t$string\t$start_init\t$end_init\t$a\t$b\t$mut\t$error\t$TR_new\n";
		    $tmp .= "$id\tVR\t+\t*\t*\t$c\t$d\t$mut\t$error\t$VR_new\n";
		    $result +=1;
		    if($a <= $total_start && $a <= $c){
			$total_start = $a;
		    }
		    elsif($c<=$total_start){$total_start = $c;}
		    
		    if($b >= $total_end && $b >= $d){
			$total_end = $b;
		    }
		    elsif($d>=$total_end){$total_end = $d;}
		}
	    }
	}
    }
    
    
    #search for negative string
    my $seq1 = myReverse($seq);
    for(my $i=0;$i<length($seq1)-length($TR);$i++){
	if($i+length($TR)-1 < length($seq1)-1-$end_init || $i > length($seq1)-1-$start_init){
	    # TR and VR are not allowed to overlap in the position, regardless of the direction
	    my $index = 0;
	    my $substr = substr($seq1,$i,length($TR));
	        
	    my $error = 0;
	    my $mut = 0;

	    my $mutation = "";

	    for(my $j=0;$j<$len;$j++){
		my $char1 = substr($TR,$j,1);
		my $char2 = substr($substr,$j,1);

		if($char1 eq 'A' && $char1 ne $char2 ){
		    $mut++;
		}
		elsif($char1 ne 'A' && $char1 ne $char2 ){
		    $mutation .= "$char1-$char2;";
		    $error += 1;
		    if($error > $miss){
			$index = 1;
			last;
		    }
		}
	    }
	        
	    if($index == 0){ ## a VR founded,then extention is carried on
		if($mutation ne ""){
		    ;#print "mutation:$mutation\n";
		}
		my ($left,$right)=(1,1);
		for($left=1;$i-$left >= 0 && $start-$left >= 0;$left++){
		    my $char1 = substr($seq2,$start-$left,1); #TR
		    my $char2 = substr($seq1,$i-$left,1); #VR
		    if($char1 eq 'A' && $char1 ne $char2 ){
			$mut++;
		    }
		    elsif($char1 ne 'A' && $char1 ne $char2){
			last;
		    }
		}
		for($right=1;$i+$len-1+$right < length($seq) && $end+$right < length($seq);$right++){
                    my $char1 = substr($seq2,$end+$right,1);
                    my $char2 = substr($seq1,$i+$len-1+$right,1);
		    if($char1 eq 'A' && $char1 ne $char2 ){
			$mut++;
		    }
		    elsif($char1 ne 'A' && $char1 ne $char2){
                        last;
                    }
                }
		$left -= 1;
		$right -= 1;
		
		my ($a,$b,$c,$d)=($start-$left,$end+$right,$i-$left,$i+$len-1+$right);
		my $TR_new = substr($seq2,$a,$b-$a+1);
                my $VR_new = substr($seq1,$c,$d-$c+1);
		
		my $num_tmp = $c;
		$c = length($seq1)-1-$d;
		$d = length($seq1)-1-$num_tmp;

		if($string eq '-'){
		    $num_tmp = $a;
                    $a = length($seq2)-1-$b;
                    $b = length($seq2)-1-$num_tmp;
                }
		
		if(length($TR_new) == length($VR_new) && length($TR_new) >= $LEN && reCheck($TR_new,$VR_new,$mut,$error,$identity) == 0){
		    # a TR-VR pair found, check the length, substitution number and identity
		    
		    $tmp .= "$id\tTR\t$string\t$start_init\t$end_init\t$a\t$b\t$mut\t$error\t$TR_new\n";
		    $tmp .= "$id\tVR\t-\t*\t*\t$c\t$d\t$mut\t$error\t$VR_new\n";
		    $result +=1;
		    if($a <= $total_start && $a <= $c){
			$total_start = $a;
		    }
		    elsif($c<=$total_start){$total_start = $c;}
		    
		    if($b >= $total_end && $b >= $d){
			$total_end = $b;
		    }
		    elsif($d>=$total_end){$total_end = $d;}
		    #}
		}
	    }
	}
    }

    return ($tmp,$result,$total_start,$total_end);
}

sub reCheck{
    my ($TR,$VR,$mutA,$mutNA,$identity) = @_;
    my ($mut,$err) = (0,0);
    my $same = 0;
    for(my $i=0;$i<length($TR);$i++){
	my $char1 = substr($TR,$i,1);
	my $char2 = substr($VR,$i,1);
	if($char1 ne $char2){
	    if($char1 eq 'A'){
		$mut ++;
	    }
	    else{
		$err ++;
	    }
	}
	else{
	    $same += 1;
	}
    }
    my $identityPair = sprintf("%0.2f",$same/length($TR));
    if($mut == $mutA && $err == $mutNA && $identityPair >= $identity ){
	return 0;
    }
    else{
	return -1;
    }
}

sub numNA{ #count the number of nucleotide notA
    my ($seq) = @_;
    my $num = 0;
    for(my $i=0;$i<length($seq);$i++){
	my $char = substr($seq,$i,1);
	if($char ne 'A'){
	    $num++;
	}
    }
    return $num;
}

sub myReverse{
    my ($seq) = @_;
    my $new="";
    for(my $i=length($seq)-1;$i>=0;$i--){
	my $char = substr($seq,$i,1);
	if($char eq 'A' || $char eq 'a'){$new .= 'T';}
	elsif($char eq 'T' || $char eq 't'){$new .= 'A';}
	elsif($char eq 'C' || $char eq 'c'){$new .= 'G';}
	elsif($char eq 'G' || $char eq 'g'){$new .= 'C';}
	else{
	    $new .= $char;
	}
    }
    return $new;
}

close OUT;close REF;
exit;
