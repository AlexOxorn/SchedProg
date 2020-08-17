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

my $data   = {};
my $totals = {};

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

    foreach my $semester ( $self->semesters ) {
        $data->{$semester}   = [];
        $totals->{$semester} = [];
    }

    $self->{-frame} = $frame;
    $self->refresh($schedule_ref);
    $self->{-data}   = {};
    $self->{-totals} = {};
    return $self;
}

sub data {
    my $self     = shift;
    my $semester = shift;
    $self->{-data}{$semester} = [] unless $self->{-data}{$semester};
    return $data->{$semester};
}

sub totals {
    my $self     = shift;
    my $semester = shift;
    $self->{-totals}{$semester} = [] unless $self->{-totals}{$semester};
    return $totals->{$semester};
}

sub reset_data {
    my $self     = shift;
    my $semester = shift;
    undef $self->{-data}{$semester};
    $self->{-data}{$semester} = [];
}

sub reset_totals {
    my $self     = shift;
    my $semester = shift;
    undef $self->{-totals}{$semester};
    $self->{-totals}{$semester} = [];
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
# refresh -> create a new pane for each semester if not already done
#            and then create the allocation grid for each semester
# ============================================================================
sub refresh {
    my $self  = shift;
    my $panes = $self->panes;

    my $yscroll;
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

    foreach my $semester ( $self->semesters ) {

        # make new frame if if does not already exist
        unless ( $panes->{$semester} ) {

            # make new frame
            $panes->{$semester} =
              $self->{-scrolledframe}->Pane( -sticky => "nsew" );
        }

        # create an allocation grid for this semester
        my $schedule = $Schedules{$semester};
        my @courses =
          sort { $a->number cmp $b->number }
          grep { $_->needs_allocation } $schedule->all_courses();

        $self->create_allocation_grid( $semester, $semester,
            $panes->{$semester} );
    }

    # now that the grids are drawn, display the semester them
    # using the grid window manager
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
# create_allocation_grid
# ============================================================================

sub create_allocation_grid {
    my $self     = shift;
    my $label    = shift;    # currently not used
    my $semester = shift;
    my $frame    = shift;
    my $col_numbers;
    $self->reset_data($semester);
    $self->reset_totals($semester);

    # ------------------------------------------------------------------------
    # create arrays with the appropriate text
    # ------------------------------------------------------------------------
    my @teachers = sort { $a->firstname cmp $b->firstname }
      $Schedules{$semester}->all_teachers;
    my @teachers_text = map { $_->firstname } @teachers;

    my @courses = grep { $_->needs_allocation }
      sort { $a->number cmp $b->number } $Schedules{$semester}->courses->list;
    my @courses_text =
      map { my $txt = $_->number; $txt =~ s/^\s*\d\d\d-//; $txt; } @courses;
    my @courses_balloon = map { $_->name; } @courses;

    my @sections_text;
    my @sections;
    foreach my $course (@courses) {
        my @new_sections = sort { $a->number cmp $b->number } $course->sections;
        push @sections,      @new_sections;
        push @sections_text, map { $_->number } @new_sections;
        push @$col_numbers,  scalar(@new_sections);
    }

    # ------------------------------------------------------------------------
    # create arrays that have the data for hrs / teacher / section
    # ------------------------------------------------------------------------
    my @totals_CI1_vars;
    my @totals_CI2_vars;
    my @totals_release_vars;
    my @totals_CIYear_vars;
    my @bound_vars;
    my $col = 0;

    # foreach course/section/teacher, holds the number of hours
    foreach my $course (@courses) {
        foreach
          my $section ( sort { $a->number cmp $b->number } $course->sections )
        {
            my $row = 0;
            foreach my $teacher (@teachers) {
                $self->data($semester)->[$row][$col] = {
                    -teacher => $teacher,
                    -course  => $course,
                    -section => $section,
                    -value   => ""
                };
                $bound_vars[$row][$col] =
                  \$self->data($semester)->[$row][$col]{-value};

                # set the current hours based on info in the schedule
                if ( $section->has_teacher($teacher) ) {
                    $self->data($semester)->[$row][$col]{-value} =
                      $section->get_teacher_allocation($teacher);
                }
                $row++;

            }
            $col++;
        }
    }

    # foreach teacher, holds the number of CI (before Release), CI after release
    # and CI (total for the year)
    my $row = 0;
    my @bound_totals;
    foreach my $teacher (@teachers) {
        my $release = "";
        $release = sprintf( "%6.3f", $teacher->release ) if $teacher->release;
        my $CI = CICalc->new($teacher)->calculate( $Schedules{$semester} );

        my $info = {
            -teacher  => $teacher,
            -CI_calc  => $CI,
            -CI_total => "",
            -release  => $release,
        };
        $self->totals($semester)->[$row] = $info;
        $bound_totals[$row][1] = \$self->totals($semester)->[$row]->{-CI_calc};
        $bound_totals[$row][0] = \$self->totals($semester)->[$row]->{-release};
        $bound_totals[$row][2] =
          \$self->totals($semester)->[$row]->{-CI_total};

        $row++;
    }

    # ------------------------------------------------------------------------
    # if we already have an AllocationGrid, and the number of row/cols
    # is consistent with our needs, then do nothing, else,
    # remove all widgets and start over
    # ------------------------------------------------------------------------

    my $rows = scalar(@teachers_text);
    unless ( $self->gui_grid($semester)
        && !$self->has_grid_size_changed( $semester, $rows, $col_numbers ) )
    {
        my $grid = AllocationGrid->new(
            $frame,
            $rows,
            $col_numbers,
            [3],
            $Colours,
            $Fonts,
            sub { validate_number( $self, $semester, @_ ) },
            sub { process_data_entry( $self, $semester, @_ ) }
        );
        $self->gui_grid( $semester, $grid );
    }

    $self->num_rows( $semester, $rows );
    $self->column_numbers( $semester, $col_numbers );

    # ------------------------------------------------------------------------
    # set up the binding of the data to the gui elements in gui_grid
    # ------------------------------------------------------------------------
    $self->gui_grid($semester)->populate(
        \@courses_text,  \@courses_balloon,
        \@sections_text, \@teachers_text,
        \@bound_vars, [""],
        [qw(RT CI YEAR)], \@bound_totals
    );

    $self->update_all_CI($semester);

}

sub validate_number {
    my $self     = shift;
    my $semester = shift;
    my $row      = shift;
    my $col      = shift;
    my $totals   = $self->totals($semester)->[$row];

    my $maybe_number = shift;

    if (   $maybe_number =~ /^\s*$/
        || $maybe_number =~ /^(\s*\d*)(\.?)(\d*\s*)$/ )
    {
        $totals->{-CI_calc}  = "";
        $totals->{-CI_total} = "";
        return 1;
    }
    return 0;
}

sub update_all_CI {
    my $self     = shift;
    my $semester = shift;
    my $totals   = $self->totals($semester);
    my %all_semesters;

    # update for this semester only
    my $row = 0;
    foreach my $total (@$totals) {
        my $teacher = $total->{-teacher};
        $total->{-CI_calc} =
          CICalc->new($teacher)->calculate( $Schedules{$semester} );
        $all_semesters{ $teacher->firstname . " " . $teacher->lastname } =
          $total->{-CI_calc};
        $row++;
    }

    # get totals for all semesters
    foreach my $sem ( $self->semesters ) {
        next if $sem eq $semester;
        my $tots = $self->totals($sem);
        foreach my $tot (@$tots) {
            my $teacher = $tot->{-teacher};
            $all_semesters{ $teacher->firstname . " " . $teacher->lastname } +=
              $tot->{-CI_calc};
        }
    }

    # update the total CI on the grid
    foreach my $sem ( $self->semesters ) {
        my $tots = $self->totals($sem);
        foreach my $tot (@$tots) {
            my $teacher = $tot->{-teacher};
            $tot->{-CI_total} =
              $all_semesters{ $teacher->firstname . " " . $teacher->lastname };
        }
    }

}

sub process_data_entry {
    no warnings;
    my $self     = shift;
    my $semester = shift;
    my $row      = shift;
    my $col      = shift;
    my $data = $self->data($semester)->[$row][$col];
    my $teacher = $data->{-teacher};
    my $section = $data->{-section};
    my $hours = $data->{-value};
    $section->set_teacher_allocation($teacher,$hours);
    $self->update_all_CI($semester);
    $$Dirty_ptr = 1;
}

# ============================================================================
# Set the Total
# ============================================================================
sub calculate_CI {
    my $self     = shift;
    my $semester = shift;
    my $teacher  = shift;

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
