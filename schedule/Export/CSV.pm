#!/usr/bin/perl
use strict;
use warnings;

package CSV;
use FindBin;
use lib "$FindBin::Bin/..";

use Text::CSV;
use Schedule::Schedule;

use Data::Dumper;

=head1 NAME

Excel - export Schedule to Excel format. 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    my $excel = Export::Excel->new();
    $excel->export();


=head1 DESCRIPTION



=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates a Excel export object

B<Parameters>

TODO
-mw => MainWindow to create new Views from

-dirtyFlag => Flag to know when the GuiSchedule has changed since last save

-schedule => where course-sections/teachers/labs/streams are defined 

B<Returns>

GuiSchedule object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
	my $class = shift;
	##??? confess "Bad inputs" if @_%2;

	my %inputs      = @_;
	my $output_file = $inputs{-output_file} || undef;
	my $schedule    = $inputs{-schedule} || undef;

	my $self = {};
	bless $self, $class;
	$self->output_file($output_file);
	$self->schedule($schedule);

	return $self;
}

# =================================================================
# output_file
# =================================================================

=head2 output_file ( [outputFileName] )

Gets and sets the output file name.

=cut

sub output_file {
	my $self = shift;
	$self->{-output_file} = shift if @_;
	return $self->{-output_file};
}

# =================================================================
# schedule
# =================================================================

=head2 schedule ( [schedule] )

Gets and sets the schedule.

=cut

sub schedule {
	my $self = shift;
	$self->{-schedule} = shift if @_;
	return $self->{-schedule};
}

# =================================================================
# export
# =================================================================

=head2 export ( )

Export to file.

=cut

sub export {
	my $self = shift;

	my @flatBlocks;

	my $titleLine = [
		"Discipline",
		"Course Name",
		"Course No.",
		"Sections",
		"Ponderation",
		"Start time",
		"End time",
		"Days",
		"Type",
		"Max",
		"Teacher Last Name",
		"Teacher First Name",
		"Teacher ID",
		"Room",
		"Other Rooms Used",
		"Restriction",
		"Travel Fees",
		"Approx. Material Fees"
	];
	push( @flatBlocks, $titleLine );

	my %dayNames = (
		1 => 'Monday',
		2 => 'Tuesday',
		3 => 'Wednesday',
		4 => 'Thursday',
		5 => 'Friday'
	);

	foreach my $course ( sort { $a->number cmp $b->number }
		$self->schedule->courses->list )
	{
		foreach my $section ( $course->sections ) {
			foreach my $block ( $section->blocks ) {

				my $start = _military_time( $block->start_number );
				my $end =
				  _military_time( $block->start_number + $block->duration );

				# split rooms into "first" and a comma-seperated "rest"
				my @rooms     = @{ $block->labs };
				my $firstRoom = $rooms[0];
				shift(@rooms);
				my $remainingRooms = join( ",", @rooms );

				foreach my $teacher ( $block->teachers ) {
					my $teacherLName = $teacher->lastname;
					my $teacherFName = $teacher->firstname;
					my $teacherID    = $teacher->id;

					push(
						@flatBlocks,
						[
							"420"    # Discipline
							, $course->name                   # Course Name
							, $course->number                 # Course No.
							, $section->number                # Sections
							, 90                              # Ponderation
							, $start                          # Start time
							, $end                            # End time
							, $dayNames{ $block->day_number } # Days
							, "C+-Lecture & Lab combined"     # Type
							, 30                              # Max
							, $teacherLName                   # Teacher L Name
							, $teacherFName                   # Teacher F Name
							, $teacherID                      # Teacher ID;
							, $firstRoom                      # Room
							, $remainingRooms                 # Other Rooms Used
							, ""                              # Restriction
							, ""                              # Travel Fees
							, ""    # Approx. Material Fees
						]
					);

				}
			}
		}
	}

	open my $fh, ">", $self->output_file or die $!;
	my $csv = Text::CSV->new();
	foreach my $flatBlock (@flatBlocks) {
		
		$csv->print( $fh, $flatBlock );
		
	}
	close $fh or die $!;
}

# =====================================================
# import CSV
# =====================================================

sub import_csv {

	

	my $Schedule2 = Schedule->new();
	my $Courses   = $Schedule2->courses;
	my $Teachers  = $Schedule2->teachers;
	my $Labs      = $Schedule2->labs;
	my $Streams   = $Schedule2->streams;

	my %repeateTeacherName;

	my $class = shift;
	my $file  = shift;
	unless ($file) {
		print "Need CSV file\n";
		return;
	}

	my $csv = Text::CSV->new(
		{
			binary    => 1,
			auto_diag => 1,
			sep_char  => ','    # not really needed as this is the default
		}
	);

	
	open( my $data, '<:encoding(utf8)', $file )
	  or die "Could not open '$file' $!\n";
	

	my $fields = $csv->getline($data);

	my $debug = 1;
	while ( my $fields = $csv->getline($data) ) {
		

		

		# [0 Constant] Displine (420)

		# [1] Course Name
		# [2] Course Number
		my $course = $Courses->get_by_number( $fields->[2] );
		unless ($course) {
			$course =
			  Course->new( -name => $fields->[1], -number => $fields->[2] );
			$Courses->add($course);
		}

		# [3] Section Number
		my $section = $course->get_section( $fields->[3] );
		unless ($section) {
			$section = Section->new( -number => $fields->[3], -hours => 0 );
			$course->add_section($section);
		}

		# [4 Constant] Ponderation (90)

		# [5] Start Time
		# [6] End Time
		my $start    = _to_hours( $fields->[5] );
		my $end      = _to_hours( $fields->[6] );
		my $duration = $end - $start;

		my $startTime;
		$startTime = int($start) . ":" . ( ( $start - int($start) ) * 60 )
		  if int($start) != $start;
		$startTime = $start . ":00" if int($start) == $start;

		

		$section->add_hours($duration);

		# [7] Day
		my $day      = "";
		my %day_dict = (qw(m Mon tu Tue w Wed th Thu f Fri sa Sat su Sun));
		foreach my $k ( keys %day_dict ) {
			do { $day = $day_dict{$k}; last } if $fields->[7] =~ /^$k/i;
		}

		my $blockNumber = $section->get_new_number;

		my $block = Block->new(
			-day      => $day,
			-start    => $startTime,
			-duration => $duration,
			-number   => $blockNumber
		);
		$section->add_block($block);

		# [8 Constant] Type (C+-Lecture & Lab combined)
		# [9 Constant] Max (30)

		# [10] Teach Last Name
		# [11] Teach First Name
		# [12] Teacher ID
		my $teacher;
		my $firstname = $fields->[11];
		my $lastname  = $fields->[10];
		my $teachID   = $fields->[12];
		if ( $teachID ne "" ) {
			unless ( $repeateTeacherName{ $firstname . $lastname }{$teachID} ) {
				$teacher = Teacher->new(
					-firstname => $firstname,
					-lastname  => $lastname
				);
				$Teachers->add($teacher);
				$repeateTeacherName{ $firstname . $lastname }{$teachID} =
				  $teacher;
			}
			else {
				$teacher =
				  $repeateTeacherName{ $firstname . $lastname }{$teachID};
			}
		}
		else {
			my $byName = $Teachers->get_by_name( $firstname, $lastname );
			unless ($byName) {
				$teacher = Teacher->new(
					-firstname => $firstname,
					-lastname  => $lastname
				);
				$Teachers->add($teacher);
			}
			else {
				$teacher = $byName;
			}
		}

		$block->assign_teacher($teacher);

		# [13] room
		my $room = $fields->[13];
		$room =~ s/\s*(.*?)\s*/$1/;
		if ($room) {
			
			my $tmpLab = $Labs->get_by_number($room);
			my $lab;
			if ($tmpLab) {
				$lab = $tmpLab;
			}
			else {
				$lab = Lab->new( -number => $room, -descr => "" );
				$Labs->add($lab);
			}

			$block->assign_lab($lab);
		}

		# [14 empty] Other used room
		# [15 empty] Restriction
		# [16 empty] Traval Fees
		# [17 empty] Aproxiamte Material Fee

	}
	if ( not $csv->eof ) {
		
		$csv->error_diag();
		return;
	}
	close $data;
	
	return $Schedule2;
}

sub _military_time {
	my $time = shift;

	my $hours = 100 * ( int($time) );

	return $hours + 30 if ( int($time) - $time );
	return $hours;

}

sub _to_hours {
	my $time = shift;

	my $hour = int( $time / 100 );
	if ( $time % 100 ) {
		$hour += .5;
	}
	return $hour;
}

1;
