#!/usr/bin/perl
use strict;
use warnings;

# TODO: Change the status bar to be able to include two files
# TODO: Fall/Winter sub-Notebooks

package NumStudents;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
use PerlLib::Colours;
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

# =================================================================
# new
# =================================================================
sub new {
    my $class        = shift;
    my $self         = bless {};
    my $frame        = shift;
    my $schedule_ref = shift;
    $Dirty_ptr = shift;
    %Schedules = (%$schedule_ref);

    $self->{-frame} = $frame;
    $self->refresh($schedule_ref);
    return $self;
}

sub _make_dialog {
    my $self  = shift;
    my $frame = $self->{-frame};
    my %panes = %{ $self->panes };
    my $col   = 0;

    # make as many panes as there are semesters
    foreach my $semester ( sort keys %Schedules ) {
        if ( $panes{$semester} ) {
            $panes{$semester}->destroy;
        }

        $panes{$semester} = $frame->Scrolled(
            "Frame",
            -scrollbars => 'oe',
            -border     => 5,
            -relief     => 'flat',
        )->grid( -column => $col, -row => 0, -sticky => 'nsew' );
        $frame->gridColumnconfigure( $col, -weight => 1 );
        $col++;
    }
    $frame->gridRowconfigure( 0, -weight => 1 );
    $self->panes( \%panes );

}

sub panes {
    my $self = shift;
    $self->{-panes} = {} unless $self->{-panes};
    $self->{-panes} = shift if @_;
    return $self->{-panes};
}

sub refresh {
    my $self         = shift;
    my $schedule_ref = shift;
    %Schedules = (%$schedule_ref);

    $self->_make_dialog();
    my %sections = ();

    foreach my $semester ( sort keys %Schedules ) {
        my $schedule = $Schedules{$semester};
        my $pane     = $self->panes->{$semester};
        next unless $pane;

        $sections{$semester} = [];

        my @courses =
          sort { $a->number cmp $b->number }
          grep { $_->needs_allocation } $schedule->all_courses();

        my $row = 0;
        foreach my $course (@courses) {
            $pane->Label(
                -text   => $course->number . " " . $course->name,
                -anchor => 'w',
                -width  => 40,
            )->grid( '-', "-", '-', -sticky => 'nsew' );
            $row++;

            foreach my $section ( sort { $a->number cmp $b->number }
                $course->sections )
            {
                $pane->Label(
                    -width  => 4,
                    -text   => $section->number,
                    -anchor => 'e',
                )->grid( -column => 0, -row => $row, -sticky => 'nsew' );

                my $student_number = $section->num_students;
                my $e = $pane->Entry(
                    -textvariable => \$student_number,
                    -justify  => 'right',
                    -validate => 'key',
                    -validatecommand => [ \&validate, $section],
                    -invalidcommand => sub { $pane->bell },
                    -width          => 8,
                  )->grid(
                    -column => 1,
                    -row    => $row,
                    -sticky => 'nw'
                  );
                $e->bind( "<Return>",  sub { $e->focusNext; } );
                $e->bind( "<FocusIn>", sub { $pane->see($e) } );

                $row++;
            }

        }

    }
}

# =================================================================
# validate that number be entered in a entry box is a real number
# (positive real number)
# =================================================================
sub validate {
    no warnings;
    my $section = shift;
    my $n       = shift;
    $n = 0 unless $n;
    if ( $n =~ /^(\s*\d*\s*)$/ ) {
        $section->num_students($n);
        $$Dirty_ptr = 1;
        return 1;
    }
    return 0;
}

1;

