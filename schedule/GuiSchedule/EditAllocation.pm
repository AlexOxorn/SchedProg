#!/usr/bin/perl
use strict;
use warnings;

package EditAllocation;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
use PerlLib::Colours;
use GuiSchedule::AllocationGrid;
use CICalculator::CICalc;
use Tk::Dialog;
use Tk::Menu;
use Tk::LabEntry;
use Tk::Pane;

#### DEBUG
my $bound_bottom;


=head1 NAME

NumStudents - provides methods/objects for entering number of students per section 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS


=head1 DESCRIPTION

Dialog for entering student numbers foreach section

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Dirty_ptr;
our %Schedules;
our $Colours;
our $Fonts;

# constants;
my $ValueKey   = "-value";
my $SectionKey = "-section";
my $CourseKey  = "-course";
my $TeacherKey = "-teacher";
my $CIKey      = "-CI";
my $CITotalKey = "-CI_total";
my $ReleaseKey = "-release";

# =================================================================
# new
# =================================================================
sub new {
    my $class        = shift;
    my $self         = bless {};
    my $frame        = shift;
    my $schedule_ref = shift;
    $Dirty_ptr = shift;
    $Colours   = shift;
    $Fonts     = shift;

    $Dirty_ptr = shift;
    %Schedules = (%$schedule_ref);

    $self->{-frame} = $frame;

    $self->draw($schedule_ref);

    return $self;
}

# ============================================================================
# has the grid size changed since last time we created it?
# ============================================================================
sub has_grid_size_changed {
    my $self     = shift;
    my $semester = shift;
    my $rows     = shift;
    my $col_nums = shift;

    # number of rows that have changed?
    return 1 unless $rows == $self->num_rows($semester);

    # foreach course, is the number of courses the same,
    # is the number of sections per course the same?

    return 1
      unless scalar(@$col_nums) ==
      scalar( @{ $self->column_numbers($semester) } );

    foreach my $sec ( 0 .. scalar(@$col_nums) - 1 ) {
        return 1
          unless $col_nums->[$sec] == $self->column_numbers($semester)->[$sec];
    }
    return;
}

# ============================================================================
# draw -> draw the semester GUI interfaces
# ============================================================================
sub draw {
    my $self  = shift;
    my $panes = $self->panes;
    my $yscroll;

    # ------------------------------------------------------------------------
    # if this is the first time, make a vertically scrolled frame
    # to hold everything else
    # ------------------------------------------------------------------------
    unless ( $self->{-scrolledframe} ) {

        $yscroll = $self->{-frame}->Scrollbar( -orient => 'vertical' )
          ->pack( -side => 'right', -fill => 'y' );
        $self->{-scrolledframe} = $self->{-frame}->Pane( -sticky => 'nsew' )
          ->pack( -side => 'top', -expand => 1, -fill => 'both' );

        # manage the scrollbar?
        $yscroll->configure(
            -command => sub {
                $self->{-scrolledframe}->yview(@_);
            }
        );
        $self->{-scrolledframe}->configure(
            -yscrollcommand => sub {
                my (@args) = @_;
                $yscroll->set(@args);
            },
        );

    }

    # ------------------------------------------------------------------------
    # Create Frames for each semseter, if they don't already exist
    # ------------------------------------------------------------------------
    foreach my $semester ( $self->semesters ) {

        # make new frame if if does not already exist
        unless ( $panes->{$semester} ) {

            # make new frame
            $panes->{$semester} =
              $self->{-scrolledframe}->Pane( -sticky => "nsew" );
        }

        # --------------------------------------------------------------------
        # create an allocation grid for this semester
        # --------------------------------------------------------------------
        my $schedule = $Schedules{$semester};
        my @courses =
          sort { $a->number cmp $b->number }
          grep { $_->needs_allocation } $schedule->all_courses();
        $self->courses(\@courses);

        $self->define_allocation_grid( $semester, $semester,
            $panes->{$semester} );
    }

    # ------------------------------------------------------------------------
    # layout the top widgets via grid manager
    # ------------------------------------------------------------------------
    # now that the grids are drawn, display the semester
    # ... thought this would be faster, it wasn't (sniff, sniff)
    my $row = 0;
    foreach my $semester ( $self->semesters ) {
        if ( $panes->{$semester} ) {
            $panes->{$semester}
              ->grid( -row => $row, -sticky => 'nswe', -column => 0 );
            $self->{-scrolledframe}->gridRowconfigure( $row, -weight => 0 );
            $row++;
        }
    }
    $self->{-scrolledframe}->gridColumnconfigure( 0, -weight => 1 );

}

# ============================================================================
# define_allocation_grid
# ============================================================================

sub define_allocation_grid {
    my $self     = shift;
    my $label    = shift;    # currently not used
    my $semester = shift;
    my $frame    = shift;
    $self->reset_data($semester);
    $self->reset_totals($semester);
    $self->reset_remaining($semester);

    # ------------------------------------------------------------------------
    # get required data
    # ------------------------------------------------------------------------
    my @teachers = sort { $a->firstname cmp $b->firstname }
      $Schedules{$semester}->all_teachers;
    $self->teachers(\@teachers);

    my @courses = $Schedules{$semester}->courses->allocation_list;
    $self->courses(\@courses);

    my @sections;
    foreach my $course (@courses) {
        my @new_sections = sort { $a->number cmp $b->number } $course->sections;
        push @sections, @new_sections;
    }
    $self->sections(\@sections);

    my @col_numbers   = map { $_->number_of_sections } @courses;

    
    # ------------------------------------------------------------------------
    # if we already have an AllocationGrid, and the number of row/cols
    # is consistent with our needs, then do nothing, else,
    # remove all widgets and start over
    # ------------------------------------------------------------------------

    my $rows = scalar(@teachers);
    unless ( $self->gui_grid($semester)
        && !$self->has_grid_size_changed( $semester, $rows, \@col_numbers ) )
    {
        my $grid = AllocationGrid->new(
            $frame,
            $rows,
            \@col_numbers,
            [3],    # totals section has 1 major column, with three sub columns within           
            $Colours,
            $Fonts,
            sub { validate_number( $self, $semester, @_ ) },
            sub { process_data_entry($self, $semester, @_)},                
            sub { my $remaining_number = shift || 0;return ! $remaining_number }
        );
        $self->gui_grid( $semester, $grid );
    }

    $self->num_rows( $semester, $rows );
    $self->column_numbers( $semester, \@col_numbers );


    # ------------------------------------------------------------------------
    # bind data to AllocationGrid
    # ------------------------------------------------------------------------
    $self->define_data_binding ($semester);  
    
    # ------------------------------------------------------------------------
    # update the CI
    # ------------------------------------------------------------------------
    $self->update_all_CI($semester);

}
    my @bound_data_vars;
    my @bound_remaining_hours;


# ============================================================================
# define all the data and bind to Allocation Grid
# ============================================================================
sub define_data_binding {
    my $self                  = shift;
    my $semester              = shift;

    # ------------------------------------------------------------------------
    # create arrays for storing the 'constant' information for the
    # AllocationGrid
    # ------------------------------------------------------------------------
    my @teachers_text = map { $_->firstname } @{$self->teachers};

    my @courses_text =
      map { my $txt = $_->number; $txt =~ s/^\s*\d\d\d-//; $txt; } @{$self->courses};
    my @courses_balloon = map { $_->name; } @{$self->courses};

    my @sections_text = map { $_->number } @{$self->sections};

    # ------------------------------------------------------------------------
    # data array and binding arrays
    # ------------------------------------------------------------------------

    # create arrays that have the data for hrs / teacher / section,
    # based on ROW/COL,
    # and create arrays for binding this information to the allocationGrid

    my $col = 0;

    # foreach course/section/teacher, holds the number of hours
    foreach my $course (@{$self->courses}) {
        foreach
          my $section ( sort { $a->number cmp $b->number } $course->sections )
        {
            my $row = 0;
            foreach my $teacher (@{$self->teachers}) {

                $self->data($semester)->[$row][$col] = {
                    $TeacherKey => $teacher,
                    $CourseKey  => $course,
                    $SectionKey => $section,
                    $ValueKey   => ""
                };

                $bound_data_vars[$row][$col] =
                  \$self->data($semester)->[$row][$col]{$ValueKey};

                # set the current hours based on info in the schedule
                if ( $section->has_teacher($teacher) ) {
                    $self->data($semester)->[$row][$col]{$ValueKey} =
                      $section->get_teacher_allocation($teacher);
                }

                $row++;

            }
            $col++;
        }
    }

    # ------------------------------------------------------------------------
    # CI, release, etc arrays and binding info
    # ------------------------------------------------------------------------

    # foreach teacher, release, CI for semester, and CI for year
    my @bound_totals;

    my $row = 0;
    foreach my $teacher (@{$self->teachers}) {
        my $release = "";
        $release = sprintf( "%6.3f", $teacher->release ) if $teacher->release;
        my $CI = CICalc->new($teacher)->calculate( $Schedules{$semester} );

        my $info = {
            $TeacherKey => $teacher,
            $CIKey      => $CI,
            $CITotalKey => "",
            $ReleaseKey => $release,
        };

        $self->totals($semester)->[$row] = $info;

        $bound_totals[$row][0] =
          \$self->totals($semester)->[$row]->{$ReleaseKey};
        $bound_totals[$row][1] = \$self->totals($semester)->[$row]->{$CIKey};
        $bound_totals[$row][2] =
          \$self->totals($semester)->[$row]->{$CITotalKey};

        $row++;
    }

    # ------------------------------------------------------------------------
    # remaining hours to be allocated, arrays and binding
    # ------------------------------------------------------------------------

    # foreach section, number of hours not yet allocated

    # foreach course/section/teacher, holds the number of hours
    $col = 0;
    my $remaining_text = \"Avail Hrs";
    foreach my $course (@{$self->courses}) {
        foreach
          my $section ( sort { $a->number cmp $b->number } $course->sections )
        {
            $self->remaining($semester)->[$col] = {
                $SectionKey => $section,
                $ValueKey   => "",#$section->hours - $section->allocated_hours,
            };

            $bound_remaining_hours[$col] =
              \$self->remaining($semester)->[$col]{$ValueKey};
        $col++;
        }
    }

    # ------------------------------------------------------------------------
    # set up the binding of the data to the gui elements in gui_grid
    # ------------------------------------------------------------------------
    $self->gui_grid($semester)->populate(
        \@courses_text,  \@courses_balloon,
        \@sections_text, \@teachers_text,
        \@bound_data_vars, [""],
        [qw(RT CI YEAR)], \@bound_totals,
        $remaining_text, \@bound_remaining_hours,
    );
    $bound_bottom = \@bound_remaining_hours;
}


# ============================================================================
# Update all the CI
# ============================================================================
sub update_all_CI {
    my $self     = shift;
    my $semester = shift;
    my $totals   = $self->totals($semester);
    my %all_semesters;

    # update for this semester only
    my $row = 0;
    foreach my $total (@$totals) {
        my $teacher = $total->{$TeacherKey};
        $total->{$CIKey} =
          CICalc->new($teacher)->calculate( $Schedules{$semester} );
        $all_semesters{ $teacher->firstname . " " . $teacher->lastname } =
          $total->{$CIKey};
        $row++;
    }
    
    # update remaining hours for this semester only
    foreach my $remaining (@{$self->remaining($semester)}) {
        my $section = $remaining->{$SectionKey};
        $remaining->{$ValueKey} = $section->hours - $section->allocated_hours;
    }

    # get totals for all semesters
    foreach my $sem ( $self->semesters ) {
        next if $sem eq $semester;
        my $tots = $self->totals($sem);
        foreach my $tot (@$tots) {
            my $teacher = $tot->{$TeacherKey};
            $all_semesters{ $teacher->firstname . " " . $teacher->lastname } +=
              $tot->{$CIKey};
        }
    }

    # update the total CI on the grid
    foreach my $sem ( $self->semesters ) {
        my $tots = $self->totals($sem);
        foreach my $tot (@$tots) {
            my $teacher = $tot->{$TeacherKey};
            $tot->{$CITotalKey} =
              $all_semesters{ $teacher->firstname . " " . $teacher->lastname };
        }
    }    

}

# ============================================================================
# validate number callback routine
# - make sure it is a number
# - invalidate the CI calculations
# ============================================================================
sub validate_number {
    my $self     = shift;
    my $semester = shift;
    my $row      = shift;
    my $col      = shift;
    my $totals   = $self->totals($semester)->[$row];
    my $remainders = $self->remaining($semester)->[$col];
 
    my $maybe_number = shift;

    if (   $maybe_number =~ /^\s*$/
        || $maybe_number =~ /^(\s*\d*)(\.?)(\d*\s*)$/ )
    {
        $totals->{$CIKey}      = "";
        $totals->{$CITotalKey} = "";
        $remainders->{$ValueKey} = "";
        return 1;
    }
    return 0;
}

# ============================================================================
# User has entered data... process it (this is a callback routine)
# ============================================================================
sub process_data_entry {
    no warnings;
    my $self     = shift;
    my $semester = shift;
    my $row      = shift;
    my $col      = shift;
 
    my $remainders = $self->remaining($semester)->[$col];
    my $data     = $self->data($semester)->[$row][$col];
    my $teacher  = $data->{$TeacherKey};
    my $section  = $data->{$SectionKey};
    my $hours    = $data->{$ValueKey};
    
    $section->set_teacher_allocation( $teacher, $hours );
    $self->update_all_CI($semester);
    $self->remaining($semester)->[$col]{$ValueKey} = $section->hours - $section->allocated_hours;    
    
    $$Dirty_ptr = 1;
}

# ============================================================================
# Set the Total CI
# ============================================================================
sub calculate_CI {
    my $self     = shift;
    my $semester = shift;
    my $teacher  = shift;

}

# ============================================================================
# storing data
# ============================================================================
my $data_semester_hash = {};

sub data {
    my $self     = shift;
    my $semester = shift;
    return $data_semester_hash->{$semester};
}

my $totals_semester_hash = {};
sub totals {
    my $self     = shift;
    my $semester = shift;
    return $totals_semester_hash->{$semester};
}

my $remaining_semester_hash = {};
sub remaining {
    my $self     = shift;
    my $semester = shift;
    return $remaining_semester_hash->{$semester};
}

sub reset_data {
    my $self     = shift;
    my $semester = shift;
    $data_semester_hash->{$semester} = [];
}

sub reset_totals {
    my $self     = shift;
    my $semester = shift;
    $totals_semester_hash->{$semester} = [];
}

sub reset_remaining {
    my $self     = shift;
    my $semester = shift;
    $remaining_semester_hash->{$semester} = [];
}

# ============================================================================
# Setters and Getters
# ============================================================================
sub column_numbers {
    my $self     = shift;
    my $semester = shift;
    $self->{-column_numbers}{$semester} = []
      unless $self->{-column_numbers}{$semester};
    $self->{-column_numbers}{$semester} = shift if @_;
    return $self->{-column_numbers}{$semester};
}

sub courses {
    my $self = shift;
    $self->{-courses} = shift if @_;
    return $self->{-courses};
}

sub teachers {
    my $self = shift;
    $self->{-teachers} = shift if @_;
    return $self->{-teachers};
}

sub sections {
    my $self = shift;
    $self->{-sections} = shift if @_;
    return $self->{-sections};
}

sub num_rows {

    my $self     = shift;
    my $semester = shift;
    $self->{-rows}{$semester} = shift if @_;
    $self->{-rows}{$semester} = 0 unless defined $self->{-rows}{$semester};
    return $self->{-rows}{$semester};
}

sub gui_grid {
    my $self     = shift;
    my $semester = shift;
    $self->{-gui_grid}{$semester} = shift if @_;
    return $self->{-gui_grid}{$semester};
}

sub panes {
    my $self = shift;
    $self->{-panes} = {} unless $self->{-panes};
    $self->{-panes} = shift if @_;
    return $self->{-panes};
}

sub semesters {
    my $self = shift;
    return ( sort keys %Schedules );
}

1;

