#!/usr/bin/perl
use strict;
use warnings;
 
use Text::CSV;
use FindBin;
use lib "$FindBin::Bin/..";
use Schedule::Schedule;
use Switch;

my $Schedule2 = Schedule->new();
my $Courses = $Schedule2->courses;
my $Teachers = $Schedule2->teachers;
my $Labs = $Schedule2->labs;
my $Streams = $Schedule2->streams;

my %repeateTeacherName;

my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
 
my $csv = Text::CSV->new ({
  binary    => 1,
  auto_diag => 1,
  sep_char  => ','    # not really needed as this is the default
});
 
my $sum = 0;
open(my $data, '<:encoding(utf8)', $file) or die "Could not open '$file' $!\n";

my $fields = $csv->getline( $data );

while (my $fields = $csv->getline( $data )) {
  
# [0 Constant] Displine (420)

# [1] Course Name
# [2] Course Number
	my $course = $Courses->get_by_number($fields->[2]);
	unless($course){
		$course = Course->new(-name => $fields->[1] , -number => $fields->[2]);
		$Courses->add($course);
	}

# [3] Section Number
	my $section = $course->get_section($fields->[3]);
	unless($section){
		$section = Section->new(-number => $fields->[3], -hours=>0);
		$course->add_section->$section;
	}

# [4 Constant] Ponderation (90)

# [5] Start Time
# [6] End Time
	my $start = _to_hours($fields->[5]);
	my $end = _to_hours($fields->[6]);
	my $duration = $end = $start;
	
	$section->add_hours($duration);

# [7] Day
	my $day = "";
	my %day_dict = (qw(m Mon tu Tue w Wed th Thu f Fri sa Sat su Sun));
	foreach my $k (keys %day_dict) {
		do {$day = $day_dict{$k} ; last} if $fields->[7] =~ /^$k/i;
	}
	
	my $block = Block->new(-day=>$day,-start=>$start,-duration=>$duration);

# [8 Constant] Type (C+-Lecture & Lab combined)
# [9 Constant] Max (30)

# [10] Teach Last Name
# [11] Teach First Name
# [12] Teacher ID
	my $teacher;
	my $firstname = $fields->[11];
	my $lastname = $fields->[10];
	my $teachID = $fields->[12];
	if($teachID ne ""){
		unless($repeateTeacherName{$firstname.$lastname}{$teachID}){
			$teacher = Teacher->new(
				-firstname=> $firstname,
				-lastname => $lastname
			);
			$repeateTeacherName{$firstname.$lastname}{$teachID} = $teacher; 
		}else{
			$teacher = $repeateTeacherName{$firstname.$lastname}{$teachID};
		}
	}else{
		my $byName = $Teachers->get_by_name($firstname,$lastname);
		unless($byName){
			$teacher = Teacher->new(
				-firstname=> $firstname,
				-lastname => $lastname
			)
		}else{
			$teacher = $byName;
		}
	}
	
	$block->assign_teacher($teacher);

# [13] room
	my $room = $fields->[13];
	my $tmpLab = $Labs->get_by_number($room);
	my $lab;
	if($tmpLab){
		$lab = $tmpLab;
	}else{
		$lab = Lab->new(-number => $room, -descr => "");
		$Labs->add($lab);
	}
	
	$block->assign_lab($lab);

# [14 empty] Other used room
# [15 empty] Restriction
# [16 empty] Traval Fees
# [17 empty] Aproxiamte Material Fee

}
if (not $csv->eof) {
  $csv->error_diag();
}
close $data;
print "$sum\n";


sub _to_hours{
	my $time = shift;
	
	my $hour = int($time / 100);
	if($time%100){
		$hour+=.5;
	}
}