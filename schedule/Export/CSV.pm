#!/usr/bin/perl
use strict;
use warnings;

package CSV;
use FindBin;
use lib "$FindBin::Bin/..";

use Text::CSV;
use Schedule::Schedule;
use Scalar::Util qw(looks_like_number);
use Carp;
use Data::Dumper;

# package variables
our $CSV_INPUT_ERRORS;

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
                      "Section",
                      "Section Name",
                      "Ponderation",
                      "Start Time",
                      "End Time",
                      "Day",
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
        foreach my $section ( sort {$a->number <=> $b->number} $course->sections ) {
            foreach my $block ( sort {$a->id <=> $b->id} $section->blocks ) {

                my $start = _military_time( $block->start_number );
                my $end =
                  _military_time( $block->start_number + $block->duration );

                # split rooms into "first" and a comma-seperated "rest"
                my @rooms     = @{ $block->labs };
                my $firstRoom = $rooms[0];
                my $Labnumber = $firstRoom->number if $firstRoom;
                $Labnumber = $Labnumber || "";
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
                           , $course->name                    # Course Name
                           , $course->number                  # Course No.
                           , $section->number                 # Section Number
                           , $section->name                   # Section Name
                           , 90                               # Ponderation
                           , $start                           # Start time
                           , $end                             # End time
                           , $dayNames{ $block->day_number }  # Days
                           , "C+-Lecture & Lab combined"      # Type
                           , 30                               # Max
                           , $teacherLName                    # Teacher L Name
                           , $teacherFName                    # Teacher F Name
                           , $teacherID                       # Teacher ID;
                           , $Labnumber                       # Room
                           , $remainingRooms                  # Other Rooms Used
                           , ""                               # Restriction
                           , ""                               # Travel Fees
                           , ""    # Approx. Material Fees
                        ]
                    );

                }
            }
        }
    }

    open my $fh, ">", $self->output_file or croak $!;
    my $csv = Text::CSV->new();
    foreach my $flatBlock (@flatBlocks) {
        $csv->print( $fh, $flatBlock );
        print $fh "\n";  # sandy added this... sometimes CSV doesn't work.  why?

    }
    close $fh or croak $!;
}

# =====================================================
# import CSV
# NOTE: croaks on Errors, so use eval blocks when
#       calling this method
# =====================================================

sub import_csv {
    my @required_headers = (
                             "Course Name",
                             "Course No.",
                             "Section",
                             "Teacher First Name",
                             "Teacher Last Name",
    );

    my $Schedule2 = Schedule->new();
    my $Courses   = $Schedule2->courses;
    my $Teachers  = $Schedule2->teachers;
    my $Labs      = $Schedule2->labs;
    my $Streams   = $Schedule2->streams;

    my %repeateTeacherName;
    my %fieldNames;

    # get parameters
    my $class = shift;
    my $file  = shift;
    unless ($file) {
        croak("Need an input file!");
    }

    # create a csv object
    my $csv = Text::CSV->new(
        {
          binary    => 1,
          auto_diag => 1,
          sep_char  => ','    # not really needed as this is the default
        }
    );

    # read the data file
    open( my $data, '<:encoding(utf8)', $file )
      or croak "Could not open '$file' $!\n";

    # get the first line so that we can get the field names
    my $fields = $csv->getline($data);
    foreach my $i ( 1 ... scalar @{$fields} ) {
        $fieldNames{ lc( $fields->[ $i - 1 ] ) } = $i - 1;
    }

    # validate that we have all the necessary field names
    foreach my $req (@required_headers) {
        croak "Missing column <$req>" unless exists $fieldNames{ lc($req) };
    }

    # ------------------------------------------------------------------------
    # now start reading the data, and interpreting it
    # ------------------------------------------------------------------------
    while ( my $fields = $csv->getline($data) ) {

        # --------------------------------------------------------------------
        # Course Name and Course No.
        # --------------------------------------------------------------------

        my $courseName = $fields->[ $fieldNames{"course name"} ];
        my $courseNo   = $fields->[ $fieldNames{"course no."} ];

        my $course = $Courses->get_by_number($courseNo);

        # create course if it doesn't already exist
        unless ($course) {
            if ( $courseName && $courseNo ) {
                $course =
                  Course->new( -name => $courseName, -number => $courseNo );
                $Courses->add($course);
            }
        }

        # --------------------------------------------------------------------
        # Section Number & Name
        # --------------------------------------------------------------------
        my $section;

        my $sectionNum  = $fields->[ $fieldNames{"section"} ];
        my $sectionName = "";
        $sectionName = $fields->[ $fieldNames{"section name"} ]
          if exists $fieldNames{"section name"};

        unless ( !$sectionNum || looks_like_number($sectionNum) ) {
            croak "Section number <$sectionNum> needs to be a number";
        }

        # create section if it doesn't already exist
        if ( $course && $sectionNum ) {
            $section = $course->get_section($sectionNum);
            unless ($section) {
                $section = Section->new(
                                         -number => $sectionNum,
                                         -hours  => 0,
                                         -name   => $sectionName
                );
                $course->add_section($section);
            }
        }
        else {
            if ( $sectionNum || $sectionName ) {
                croak "Section Can't be specified if course isn't specified";
            }
        }

        # --------------------------------------------------------------------
        # start and end time of a block
        # --------------------------------------------------------------------

        my $startIn;
        my $endIn;
        my $duration  = '';
        my $startTime = '';
        if ( $fieldNames{"start time"} && $fieldNames{"end time"} ) {
            $startIn = $fields->[ $fieldNames{"start time"} ];
            $endIn   = $fields->[ $fieldNames{"end time"} ];

            my $start = _to_hours($startIn) if $startIn;
            my $end   = _to_hours($endIn)   if $endIn;

            # add hours to the section
            if ( $section && $start && $end ) {

                $duration = $end - $start;
                croak "$courseName, $sectionName has starts before it ends"
                  if $duration < 0;

                $startTime =
                  int($start) . ":" . ( ( $start - int($start) ) * 60 )
                  if int($start) != $start;
                $startTime = $start . ":00" if int($start) == $start;

                $section->add_hours($duration);
            }
        }

        # --------------------------------------------------------------------
        # Day
        # --------------------------------------------------------------------
        my $dayInput;
        my $day = "";
        if ( $fieldNames{"day"} ) {
            $dayInput = $fields->[ $fieldNames{"day"} ];

            if ( $section && $dayInput ) {
                my %day_dict =
                  (qw(m Mon tu Tue w Wed th Thu f Fri sa Sat su Sun));
                foreach my $k ( keys %day_dict ) {
                    do { $day = $day_dict{$k}; last } if $dayInput =~ /^$k/i;
                }
            }
        }

        # --------------------------------------------------------------------
        # if we have all the info, create the block
        # --------------------------------------------------------------------
        my $block;

        if ( $section && $day && $startTime && $duration ) {
            my $blockNumber = $section->get_new_number;

            $block = Block->new(
                                 -day      => $day,
                                 -start    => $startTime,
                                 -duration => $duration,
                                 -number   => $blockNumber
            );
            $section->add_block($block);
        }
        else {
            if ( $day || $startTime || $duration ) {
                croak
                  "Block Time Can't be specified if section isn't specified";
            }
        }

        # --------------------------------------------------------------------
        # define the teacher
        # --------------------------------------------------------------------
        my $teacher;
        my $firstname = $fields->[ $fieldNames{"teacher first name"} ];
        my $lastname  = $fields->[ $fieldNames{"teacher last name"} ];

        # this is an optional field, so must check if it exists
        my $teachID = "";
        $teachID = $fields->[ $fieldNames{"teacher id"} ]
          if $fieldNames{"teacher id"};

        # must have a last name or teacher isn't assign to this block
        if ($lastname) {

            # ********* ALEX MUST COMMENT AND CLEAN UP THIS CODE! **********
            unless ($teachID) {

              # If the id is not specified get the teacher object using its name
                $teacher = $Teachers->get_by_name( $firstname, $lastname );
                unless ($teacher) {

                    #if the teacher is a new teacher, create a teacher object
                    $teacher =
                      Teacher->new( -firstname => $firstname,
                                    -lastname  => $lastname );
                    $Teachers->add($teacher);
                }
            }
            else {

                #if teacher id is specifiec, make sure the input is a number
                unless ( looks_like_number($teachID) ) {
                    croak "Teacher ID needs to be a number";
                }
                unless (
                       $repeateTeacherName{ $firstname . $lastname }{$teachID} )
                {

                    #if the specific combination of name and id is
                    # not already in the hash
                    #(not in the schedule) create a new teacher
                    $teacher =
                      Teacher->new( -firstname => $firstname,
                                    -lastname  => $lastname );
                    $Teachers->add($teacher);
                    $repeateTeacherName{ $firstname . $lastname }{$teachID} =
                      $teacher;
                }
                else {

                    #otherwise get the teacher associated with
                    # the name and id in the hash
                    $teacher =
                      $repeateTeacherName{ $firstname . $lastname }{$teachID};
                }
            }
            
            if ($block) {
                $block->assign_teacher($teacher);
            }
            elsif ($section) {
                $section->assign_teacher($teacher);
            }
            elsif ($course) {
                $course->assign_teacher($teacher);
            }
        }

        # --------------------------------------------------------------------
        # room
        # --------------------------------------------------------------------
        my $room;
        if ( $fieldNames{"room"} ) {
            $room = $fields->[ $fieldNames{"room"} ];

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

                if ($block) {
                    $block->assign_lab($lab);
                }
                elsif ($section) {
                    $section->assign_lab($lab);
                }
                elsif ($course) {
                    $course->assign_lab($lab);
                }
            }

        }
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

    unless ( looks_like_number($time) ) {
        croak "Times needs to be a number eg. (13h30 -> 1330)";
    }

    my $hour = int( $time / 100 );
    if ( $time % 100 ) {
        $hour += .5;
    }
    return $hour;
}

1;
