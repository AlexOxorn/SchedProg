#!/usr/bin/perl
use strict;
use warnings;

package CSV;
use FindBin;
use lib "$FindBin::Bin/..";

use Text::CSV;
use Schedule::Schedule;

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

    my %inputs = @_; 
    my $output_file = $inputs{-output_file} || undef;
    my $schedule = $inputs{-schedule} || undef;
    
    my $self = { };
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
    return $self->{-output_file}
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
    return $self->{-schedule}
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

    my $titleLine = [ "Discipline"
                    , "Course Name"
                    , "Course No."
                    , "Sections"
                    , "Ponderation"
                    , "Start time"
                    , "End time"
                    , "Days"
                    , "Type"
                    , "Max"
                    , "Teacher"
                    , "Room"
                    , "Other Rooms Used"
                    , "Restriction"
                    , "Travel Fees"
                    , "Approx. Material Fees"
                    ];
    push(@flatBlocks, $titleLine);
    
    my %dayNames = ( 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday' );

    foreach my $course ( sort { $a->number cmp $b->number } $self->schedule->courses->list ) {
        foreach my $section ( $course->sections ) {
            foreach my $block ( $section->blocks ) {
                
                my $start = $block->start_number * 100;
                my $end   = ($block->start_number + $block->duration) * 100;

                # split rooms into "first" and a comma-seperated "rest"
                my @rooms = @{$block->labs};
                my $firstRoom = $rooms[0];
                shift(@rooms);
                my $remainingRooms = join(",", @rooms);
                
                foreach my $teacher ( $block->teachers ) {
                    my $teacherName = $teacher->lastname . ", " . $teacher->firstname;
                    
                    push(@flatBlocks, [ "420"                         # Discipline          
                                      , $course->name                 # Course Name         
                                      , $course->number               # Course No.          
                                      , $section->number              # Sections            
                                      , 90                            # Ponderation         
                                      , $start                        # Start time          
                                      , $end                          # End time            
                                      , $dayNames{$block->day_number} # Days                
                                      , "C+-Lecture & Lab combined"   # Type                
                                      , 30                            # Max                 
                                      , $teacherName                  # Teacher             
                                      , $firstRoom                    # Room                
                                      , $remainingRooms               # Other Rooms Used    
                                      , ""                            # Restriction         
                                      , ""                            # Travel Fees         
                                      , ""                            # Approx. Material Fees
                                      ]
                        );
                    
                    
                }
            }
        }
    }
    
    open my $fh, ">", $self->output_file or die $!;
    my $csv = Text::CSV->new();
    foreach my $flatBlock (@flatBlocks) {
        $csv->print($fh, $flatBlock);
        print $fh "\n";
    }
    close $fh or die $!;
}


1;
