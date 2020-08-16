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
    $self->refresh($schedule_ref);
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
      unless scalar(@$col_nums) == scalar( @{ $self->column_numbers($semester) } );

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

    foreach my $semester ( $self->semesters ) {

        # make new frame if if does not already exist
        unless ( $panes->{$semester} ) {

            # make new frame
            $panes->{$semester} =
              $self->{-frame}->Frame( -bg => 'black' );
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
            $panes->{$semester}->grid( -row => $row, -sticky => 'nwe' );
            $self->{-frame}->gridRowconfigure( $row, -weight => 0 );
            $row++;
        }
    }
    $self->{-frame}->gridRowconfigure( $row, -weight => 1 );
    $self->{-frame}->gridColumnconfigure( 0, -weight => 1 );

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

    # ------------------------------------------------------------------------
    # create arrays with the appropriate text
    # ------------------------------------------------------------------------
    my @teachers = sort { $a->firstname cmp $b->firstname }
      $Schedules{$semester}->all_teachers;
    my @teachers_text = map  { $_->firstname } @teachers;
    my @courses       = grep { $_->needs_allocation }
      sort { $a->number cmp $b->number } $Schedules{$semester}->courses->list;
    my @courses_text =
      map { my $txt = $_->number; $txt =~ s/420-//; $txt; } @courses;

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
    my @data;
    my @bound_vars;
    my @totals_CI1_vars;
    my @totals_CI2_vars;
    my @totals_release_vars;
    my @totals_CIYear_vars;
    my @totals;
    my $col = 0;

    # foreach course/section/teacher, holds the number of hours
    foreach my $course (@courses) {
        foreach
          my $section ( sort { $a->number cmp $b->number } $course->sections )
        {
            my $row = 0;
            foreach my $teacher (@teachers) {
                $data[$row][$col] = {
                    -teacher => $teacher,
                    -course  => $course,
                    -section => $section,
                    -value   => ""
                };
                $bound_vars[$row][$col] = \$data[$row][$col]{-value};

                # set the current hours based on info in the schedule
                if ( $section->has_teacher($teacher) ) {
                    $data[$row][$col]{-value} = $section->hours;
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
        $totals[$row] = {
            -teacher           => $teacher,
            -CI_calc           => "1",
            -CI_total_semester => "2",
            -CI_total_all      => "3",
            -release           => "4",
        };
        $bound_totals[$row][0]     = \$totals[$row]{-CI_calc};
        $bound_totals[$row][1]     = \$totals[$row]{-CI_total_semester};
        $bound_totals[$row][2] = \$totals[$row]{-release};
        $bound_totals[$row][3]  = \$totals[$row]{-CI_total_all};

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
        my $grid =
          AllocationGrid->new( $frame, $rows, $col_numbers, [4], $Colours,
            $Fonts, \&validate_number, \&process_data_entry  );
        $self->gui_grid( $semester, $grid );
    }

    $self->num_rows( $semester, $rows );
    $self->column_numbers( $semester, $col_numbers );

    # ------------------------------------------------------------------------
    # set up the binding of the data to the gui elements in gui_grid
    # ------------------------------------------------------------------------
    $self->gui_grid($semester)
      ->populate( \@courses_text, \@sections_text, \@teachers_text,
        \@bound_vars, [""], [qw(CI RT CI ALL)], \@bound_totals )
      ;

}

sub validate_number {
    my $maybe_number = shift;
    if ($maybe_number =~ /^\s*$/) {
        return 1;
    }
    elsif ($maybe_number =~ /^(\s*\d*)(\.?)(\d*\s*)$/) {
        return 1;
    }
    return 0;
}

sub process_data_entry {
    print "process_data_entry: @_\n";
    return 1;
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
