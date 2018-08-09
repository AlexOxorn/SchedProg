#!/usr/bin/perl
use strict;
use warnings;

package ViewLab;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw( min max );
use GuiSchedule::GuiBlocks;
use GuiSchedule::Undo;
use GuiSchedule::ViewBase;
use Schedule::Conflict;
use Tk;
our @ISA = qw(ViewBase);

our $EarliestTime = $ViewBase::EarliestTime;
our $LatestTime   = $ViewBase::LatestTime;

=head1 NAME

View - describes the visual representation of a Window

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    Example of how to use code here

=head1 DESCRIPTION

Describes a View

=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates a View object, draws the necessary GuiBlocks and returns the View object.

B<Parameters>

-cn => Canvas for the View to draw on

-blocks => Blocks that need to be drawn on the View

-schedule => where course-sections/teachers/labs/streams are defined

-lab => Lab that the View is being made for

-btn_ptr => Reference to the button that creates this view

B<Returns>

View object

=cut

sub new {
	my $class    = shift;
	my $mw       = shift;
	my $schedule = shift;
	my $lab      = shift;

	# ---------------------------------------------------------------
	# create the ViewBase
	# ---------------------------------------------------------------
	my $self = $class->SUPER::new($mw);

	# ---------------------------------------------------------------
	# set some parameters
	# ---------------------------------------------------------------
	$self->schedule($schedule);
	$self->type("Lab");
	$self->obj($lab);
	$self->redraw();
}

sub redraw {
	my $self         = shift;
	my $obj          = $self->obj;
	my $schedule     = $self->schedule;
	my $cn           = $self->canvas;
	my $currentScale = $self->currentScale;

	$self->SUPER::redraw();

	foreach my $day ( 1 ... 5 ) {
		foreach my $start ( $EarliestTime * 2 ... ( $LatestTime * 2 ) - 1 ) {
			my @coords = $self->SUPER::get_time_coords( $day, $start / 2, 1 );
			$cn->createRectangle(
				@coords,
				-outline => 'red',
				-width   => 3
			);
		}
	}
	
}

1;
