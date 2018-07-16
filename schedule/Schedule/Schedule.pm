#!/usr/bin/perl
use strict;
use warnings;

package Schedule;

use FindBin;
use lib ("$FindBin::Bin/..");

use Carp;
use YAML;

use Schedule::Teachers;
use Schedule::Courses;
use Schedule::Conflicts;
use Schedule::Conflict;
use Schedule::Teacher;
use Schedule::Lab;
use Schedule::Labs;
use Schedule::Streams;
use Schedule::Stream;

use List::Util qw/all min max/;

=head1 NAME

Schedule - read and write schedule files

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    
    my $sched = Schedule->read('myschedule_file.txt');
    
    my $teachers = $sched->teachers;
    my $courses  = $sched->courses;
    my $conflicts = $sched->conflicts;
    
    $sched->teachers->add(...);
    $sched->course->add(...);
    $sched->calculate_conflicts(...);
    
    $sched->write('my_new_schedule_file.txt');


=head1 DESCRIPTION

This module provides the top level class for all of the schedule
objects.  

The data that creates the schedule can be saved to an external
file, or read in from an external file.

This class provides links to all the other classes
which are used to create and/or modify course schedules

=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates an empty Schedule object

B<Returns>

Schedule object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = {
                 -courses   => Courses->new(),
                 -teachers  => Teachers->new(),
                 -conflicts => Conflicts->new(),
                 -labs      => Labs->new(),
                 -streams   => Streams->new(),
               };

    bless $self, $class;
    return $self;
}

# =================================================================
# read
# =================================================================

=head2 read (I<filename.txt>)

reads a text file containing the schedule data

B<Parameters>

=over

=item * I<filename.txt> 

Name of the file containing the schedule data

=back

B<Returns>

Schedule object if successful, I<undef> if not

=cut

# -------------------------------------------------------------------
# read
#--------------------------------------------------------------------
sub read_YAML {
    my $class = shift;
    my $file  = shift;

    # create object
    my $self = Schedule->new();
    bless $self, $class;

    # if reading was successful, return object
    if ( -e $file ) {
        local $/ = undef;
        open my $fh, "<", $file or do {
            croak "Cannot read from file $file\n";
            return;
        };
        (
           $self, $Block::Max_id, $Course::Max_id, $Lab::Max_id,
           $Section::Max_id, $Teacher::Max_id, $Time_slot::Max_id,
           $Stream::Max_id,
        ) = Load(<$fh>);
        close $fh;

        return $self;
    }

    # file doesn't exist, or whatever... return false
    carp("File <$file> does not exist\n");
    return;

}

# =================================================================
# write
# =================================================================

=head2 write (I<filename.txt>)

reads a text file containing the schedule data

B<Parameters>

=over

=item * I<filename.txt> 

Name of the file to contain the schedule data

=back

B<Returns>

true if successful, false otherwise

=cut

# -------------------------------------------------------------------
# write
#--------------------------------------------------------------------
sub write_YAML {
    my $self = shift;
    my $file = shift;

    # open file or die
    open my $fh, ">", $file or do {
        croak "Cannot write to file \"$file\"";
        return;
    };

    # print YAML output
    eval {
        print $fh Dump(
                        $self,            $Block::Max_id,
                        $Course::Max_id,  $Lab::Max_id,
                        $Section::Max_id, $Teacher::Max_id,
                        $Time_slot::Max_id, $Stream::Max_id,
                      );
    };
    if ($@) {
        croak "Cannot create save data";
        close $fh;
        return;
    }

    # finish up
    close $fh;
    return 1;
}

# =================================================================
# teachers
# =================================================================

=head2 teachers ()

Returns a "Teachers" object

=cut

sub teachers {
    my $self = shift;

    # must make sure that any teacher who has been attached to a
    # course is added to this object before returning it
    foreach my $course ( $self->courses->list ) {
        foreach my $block ( $course->blocks ) {
            foreach my $teacher ( $block->teachers ) {
                $self->{-teachers}->add($teacher);
            }
        }
    }

    # return teachers object
    return $self->{-teachers};
}

# =================================================================
# streams
# =================================================================

=head2 streams ()

Returns a "Streams" object

=cut

sub streams {
    my $self = shift;

    # must make sure that any stream who has been attached to a
    # course is added to this object before returning it
    foreach my $course ( $self->courses->list ) {
        foreach my $section ( $course->sections ) {
            foreach my $stream ( $section->streams ) {
                $self->{-streams}->add($stream);
            }
        }
    }

    # return streams object
    return $self->{-streams};
}


# =================================================================
# courses
# =================================================================

=head2 courses ()

Returns a "Courses" object 

=cut

sub courses {
    my $self = shift;
    return $self->{-courses};
}

# =================================================================
# labs
# =================================================================

=head2 labs ()

Returns a "Labs" object

=cut

sub labs {
    my $self = shift;

    # must make sure that any lab which has been attached to a
    # course is added to this object before returning it
    foreach my $course ( $self->courses->list ) {
        foreach my $block ( $course->blocks ) {
            foreach my $lab ( $block->labs ) {
                $self->{-labs}->add($lab);
            }
        }
    }

    # return teachers object
    return $self->{-labs};
}

# =================================================================
# conflicts
# =================================================================

=head2 conflicts ()

Returns a reference to array of conflict objects

=cut

sub conflicts {
    my $self = shift;
    return $self->{-conflicts};
}

# =================================================================
# get section info for teacher
# =================================================================

=head2 sections_for_teacher (teacher object) 

Returns a list of courses sections that this teacher teaches

=cut

sub sections_for_teacher {
    my $self    = shift;
    my $teacher = shift;

    # --------------------------------------------------------------
    # validate input
    # --------------------------------------------------------------
    confess "<"
      . ref($teacher)
      . ">: invalid teacher - must be a Teacher object"
      unless ref($teacher) && $teacher->isa("Teacher");

    # --------------------------------------------------------------
    # loop through course->section->teachers to match teacher ids
    # --------------------------------------------------------------
    my @sections;

    foreach my $course ( $self->courses->list ) {
        foreach my $section ( $course->sections ) {
            foreach my $teacher_id ( $section->teachers ) {
                if ( $teacher->id eq $teacher_id->id ) {
                    push @sections, $section;
                }
            }
        }
    }

    if (wantarray) {
        return @sections;
    }
    else {
        return \@sections;
    }
}

# =================================================================
# get block info for teacher
# =================================================================

=head2 blocks_for_teacher (teacher object) 

Returns a list of courses blocks that this teacher teaches

=cut

sub blocks_for_teacher {
    my $self    = shift;
    my $teacher = shift;

    # --------------------------------------------------------------
    # validate input
    # --------------------------------------------------------------
    confess "<"
      . ref($teacher)
      . ">: invalid teacher - must be a Teacher object"
      unless ref($teacher) && $teacher->isa("Teacher");

    # --------------------------------------------------------------
    # loop through course->block->teachers to match teacher ids
    # --------------------------------------------------------------
    my @blocks;

    foreach my $course ( $self->courses->list ) {
        foreach my $block ( $course->blocks ) {
            foreach my $teacher_test ( $block->teachers ) {
                if ( $teacher->id eq $teacher_test->id ) {
                    push @blocks, $block;
                }
            }
        }
    }

    if (wantarray) {
        return @blocks;
    }
    else {
        return \@blocks;
    }
}

# =================================================================
# get block info for lab
# =================================================================

=head2 blocks_in_lab (room number) 

Returns a list of courses blocks in this lab

=cut

sub blocks_in_lab {
    my $self = shift;
    my $lab  = shift;

    # --------------------------------------------------------------
    # validate inputs
    # --------------------------------------------------------------
    confess "<" . ref($lab) . ">: invalid lab - must be a Lab object"
      unless ref($lab) && $lab->isa("Lab");

    # --------------------------------------------------------------
    # loop through course->block-labs to match lab-ids
    # --------------------------------------------------------------
    my %blocks;

    foreach my $course ( $self->courses->list ) {
        foreach my $block ( $course->blocks ) {
            foreach my $lab_test ( $block->labs ) {
                if ( $lab->id eq $lab_test->id ) {
                    $blocks{$block} = $block;
                }
            }
        }
    }

    if (wantarray) {
        return values %blocks;
    }
    else {
        return [ values %blocks ];
    }
}

# =================================================================
# get section info for streams
# =================================================================

=head2 sections_for_streams (streams object) 

Returns a list of courses sections that are assigned to this stream

=cut

sub sections_for_stream {
    my $self    = shift;
    my $stream = shift;

    # --------------------------------------------------------------
    # validate input
    # --------------------------------------------------------------
    confess "<"
      . ref($stream)
      . ">: invalid stream - must be a Stream object"
      unless ref($stream) && $stream->isa("Stream");

    # --------------------------------------------------------------
    # loop through course->section->streams to match stream ids
    # --------------------------------------------------------------
    my @sections;

    foreach my $course ( $self->courses->list ) {
        foreach my $section ( $course->sections ) {
            foreach my $stream_id ( $section->streams ) {
                if ( $stream->id eq $stream_id->id ) {
                    push @sections, $section;
                }
            }
        }
    }

    if (wantarray) {
        return @sections;
    }
    else {
        return \@sections;
    }
}

# =================================================================
# get block info for this streams
# =================================================================

=head2 blocks_for_stream (stream object) 

Returns a list of courses blocks that is in this stream

=cut

sub blocks_for_stream {
    my $self    = shift;
    my $stream = shift;

    my @sections = $self->sections_for_stream($stream);
    my @blocks;
    
    foreach my $section (@sections) {
        push @blocks, $section->blocks;
    }


    if (wantarray) {
        return @blocks;
    }
    else {
        return \@blocks;
    }
}

# =================================================================
# get list of all teachers
# =================================================================

=head2 all_teachers 

Returns a list of all teachers in this schedule

=cut

sub all_teachers {
    my $self = shift;
    if (wantarray) {
        return $self->teachers->list;
    }
    else {
        return scalar( $self->teachers->list );
    }
}

# =================================================================
# get list of all streams
# =================================================================

=head2 all_streams 

Returns a list of all streams in this schedule

=cut

sub all_streams {
    my $self = shift;
    if (wantarray) {
        return $self->streams->list;
    }
    else {
        return scalar( $self->streams->list );
    }
}

# =================================================================
# get list of all courses
# =================================================================

=head2 all_courses 

Returns a list of all courses in this schedule

=cut

sub all_courses {
    my $self = shift;
    if (wantarray) {
        return $self->courses->list;
    }
    else {
        return scalar( $self->courses->list );
    }
}

# =================================================================
# get all used labs
# =================================================================

=head2 all_labs() 

Returns a list of all labs used for this schedule

=cut

sub all_labs {
    my $self = shift;
    if (wantarray) {
        return $self->labs->list;
    }
    else {
        return scalar( $self->labs->list );
    }
}

# =================================================================
# remove course
# =================================================================

=head2 remove_course() 

Removes course from schedule

=cut

sub remove_course {
    my $self = shift;
    my $course = shift;
    $self->courses->remove($course);
}

# =================================================================
# remove teacher
# =================================================================

=head2 remove_teacher() 

Removes teacher from schedule

=cut

sub remove_teacher {
    my $self = shift;
    my $teacher = shift;
    
    # make sure we have a valid teacher as input
        confess "<"
          . ref($teacher)
          . ">: invalid teacher - must be a Teacher object"
          unless ref($teacher) && $teacher->isa("Teacher");

    # go through all the blocks in this schedule, and
    # remove teacher from all the blocks
    foreach my $course ($self->all_courses) {
        foreach my $block ($course->blocks) {
            $block->remove_teacher($teacher);
        }
    }
    
    # now delete teacher from list of teachers
    $self->teachers->remove($teacher);    
}

# =================================================================
# remove lab
# =================================================================

=head2 remove_lab() 

Removes lab from schedule

=cut

sub remove_lab {
    my $self = shift;
    my $lab = shift;
    
    # make sure we have a valid lab as input
        confess "<"
          . ref($lab)
          . ">: invalid lab - must be a Lab object"
          unless ref($lab) && $lab->isa("Lab");

    # go through all the blocks in this schedule, and
    # remove lab from all the blocks
    foreach my $course ($self->all_courses) {
        foreach my $block ($course->blocks) {
            $block->remove_lab($lab);
        }
    }
    
    # now delete lab from list of labs
    $self->labs->remove($lab);    
}

# =================================================================
# remove stream
# =================================================================

=head2 remove_stream() 

Removes stream from schedule

=cut

sub remove_stream {
    my $self = shift;
    my $stream = shift;
    
    # make sure we have a valid stream as input
        confess "<"
          . ref($stream)
          . ">: invalid stream - must be a Stream object"
          unless ref($stream) && $stream->isa("Stream");

    # go through all the sections in this schedule, and
    # remove stream from all the sections
    foreach my $course ($self->all_courses) {
        foreach my $section ($course->sections) {
            $section->remove_stream($section);
        }
    }
    
    # now delete stream from list of streams
    $self->streams->remove($stream);    
}

# =================================================================
# calculate conflicts
# =================================================================

=head2 calculate_conflicts ()

Reviews the schedule, and creates an array of conflict objects,
as necessary

Returns schedule object

=cut

sub calculate_conflicts {
    my $self = shift;

    # create list of all blocks from the list of courses
    my @all_blocks;
    foreach my $course ( @{ $self->courses->list } ) {
        push @all_blocks, $course->blocks;
    }

    # reset the conflict list
    $self->{-conflicts} = Conflicts->new();

    # reset all block's conflicted tag
    foreach my $block (@all_blocks) {
        $block->reset_conflicted();
    }

    # check all block pairs to see if there is a time overlap
    
    for (my $i = 0; $i < scalar(@all_blocks); $i++) {
        my $block1 = $all_blocks[$i];

        for(my $j = $i + 1; $j < scalar(@all_blocks); $j++) {
            my $block2 = $all_blocks[$j];

            # skip if we have identical blocks (should not occur)
            next if ($block1->id == $block2->id);

            # test that the blocks overlap, but only if they have the same teacher/lab/stream (TODO)
            if ($block1->conflicts_time($block2)
                &&
                ! _disjoint($block1, $block2))
            {

                    # creat a conflict object and mark the blocks as conflicting
                my @blocks = ($block1, $block2);
                $self->conflicts->add( -type   => Conflict->TIME
                                     , -blocks => \@blocks
                                     );
                $block1->conflicted(Conflict->TIME);
                $block2->conflicted(Conflict->TIME);
            }
        }
    }

    # check for lunch break conflicts by teacher
    my $start_lunch = 11;
    my $end_lunch = 14;
    my @lunch_periods = map {$_,$_+.5} ($start_lunch .. $end_lunch-1);
    foreach my $teacher ($self->teachers->list) {

            # filter to only blocks can can possibly conflict
            my @relevantBlocks = grep {$_->start_number < $end_lunch && $_->start_number + $_->duration > $start_lunch} $self->blocks_for_teacher($teacher);

            # collect blocks by day
            my %blocksByDay;
            foreach my $block (@relevantBlocks) {
                    push @{$blocksByDay{$block->day_number}}, $block;
            }

            foreach my $day (keys %blocksByDay) {
                    my @blocks = @{$blocksByDay{$day}};
                    continue if(scalar(@blocks) == 0);

                    # check for the existence of a lunch break in any of the possible :30 periods between 11:00 and 13:00
                    my $hasLunch = 0;
                    foreach my $lunchStart (@lunch_periods) {
                            # is this period free?
                            $hasLunch = all { !_conflictLunch($_, $lunchStart) } @blocks;
                           last if($hasLunch);
                    }

                    if(!$hasLunch) {
                            # create a conflict object and mark the blocks as conflicting.
                            $self->conflicts->add( -type   => Conflict->LUNCH
                                                 , -blocks => \@blocks
                                                 );                            
                            map { $_->conflicted(Conflict->LUNCH) } @blocks; 
                    }
            }     
    }

    # check for 4 day schedule for teacher, also for 32 hours availability (max)
    foreach my $teacher ($self->teachers->list) {

            # skip teachers with release time
			no warnings;
            next if($teacher->release ne "" && $teacher->release > 0);
            
            # collect blocks by day
            my %blocksByDay;
            foreach my $block ($self->blocks_for_teacher($teacher)) {
                    push @{$blocksByDay{$block->day_number}}, $block;
            }

            my $dayCount = 0;
            foreach my $day (keys %blocksByDay) {
                    $dayCount++ if(scalar(@{$blocksByDay{$day}}) > 0);
            }

            if($dayCount < 4) {
                    # create a conflict object and mark the blocks as conflicting.
                    $self->conflicts->add( -type   => Conflict->MINIMUM_DAYS
                                         , -blocks => \@{$self->blocks_for_teacher($teacher)}
                                         );                            
                    map { $_->conflicted(Conflict->MINIMUM_DAYS) } $self->blocks_for_teacher($teacher);
            }

            # compute weekly availability for the teacher
            my $availability = 0;
            foreach my $day (keys %blocksByDay) {
                    my $dayStart = min(map {$_->start_number} @{$blocksByDay{$day}});
                    my $dayEnd   = max(map {$_->start_number + $_->duration} @{$blocksByDay{$day}});
                    continue if($dayEnd <= $dayStart);
                    $availability += $dayEnd - $dayStart - 0.5;
            }

            # if over limit, then create the conflict.
            if($availability > 32) {
                   # create a conflict object and mark the blocks as conflicting.
                    $self->conflicts->add( -type   => Conflict->AVAILABILITY
                                         , -blocks => \@{$self->blocks_for_teacher($teacher)}
                                         );                            
                    map { $_->conflicted(Conflict->AVAILABILITY) } $self->blocks_for_teacher($teacher);
            }                    
            
    }

    
 
    return $self;
}

sub _conflictLunch($$) {
        my $block = shift;
        my $lunchStart = shift;

        my $lunchEnd = $lunchStart + 0.5;
        my $blockEndNumber = $block->start_number + $block->duration;
        return ($block->start_number < $lunchEnd && $lunchStart < $blockEndNumber)
                  ||
               ($lunchStart < $blockEndNumber && $block->start_number < $lunchEnd);
}

### TODO maybe replace with Teachers::disjoint 

sub _disjoint {
    my $block1 = shift; 
    my $block2 = shift;

    # to compute the disjoint of 2 sets, count occurences in both sets and ensure that all values are < 2
    my %teacher_occurences;

    # get all the teachers the first and second set.
    foreach my $teacher ($block1->teachers) {
        $teacher_occurences{$teacher->id}++;
    }
    foreach my $teacher ($block2->teachers) {
        $teacher_occurences{$teacher->id}++;
    }

    # a teacher count of 2 means that they are in both sets.
    foreach my $count (values %teacher_occurences) {
        return 0 if ($count >= 2);
    } 

    # same for labs
    my %lab_occurences;

    foreach my $lab ($block1->labs) {
        $lab_occurences{$lab->id}++;
    }
    foreach my $lab ($block2->labs) {
        $lab_occurences{$lab->id}++;
    }

    foreach my $count (values %lab_occurences) {
        return 0 if ($count >= 2);
    } 

    # same for streams
    my %stream_occurences;

    foreach my $stream ($block1->section->streams) {
        $stream_occurences{$stream->id}++;
    }
    foreach my $stream ($block2->section->streams) {
        $stream_occurences{$stream->id}++;
    }

    foreach my $count (values %stream_occurences) {
        return 0 if ($count >= 2);
    } 
    
    return 1;
}

# =================================================================
# footer
# =================================================================


=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;