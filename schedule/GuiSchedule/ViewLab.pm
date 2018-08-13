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
use GuiSchedule::AssignBlock;
use Tk;
our @ISA = qw(ViewBase);

our $EarliestTime = $ViewBase::EarliestTime;
our $LatestTime   = $ViewBase::LatestTime;

my $AssignBlocks;

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
	$self->type("lab");
	$self->obj($lab);
	$self->redraw();

}

sub redraw {
	my $self         = shift;
	my $obj          = $self->obj;
	my $schedule     = $self->schedule;
	my $cn           = $self->canvas;
	my $currentScale = $self->currentScale;

	my %dayTag = (
		"1" => "monday",
		"2" => "tuesday",
		"3" => "wednesday",
		"4" => "thursday",
		"5" => "friday"
	);

	$self->SUPER::redraw();
	
	#Loop through each half hour time slot, and create an AsignBlock for each
	my @allBlocks;
	foreach my $day ( 1 ... 5 ) {
		foreach my $start ( $EarliestTime * 2 ... ( $LatestTime * 2 ) - 1 ) {
			push( @allBlocks, AssignBlock->new( $self, $day, $start / 2 ) );
		}
	}
	
	#BINDS MOUSE 1 to the setup of AssignBlock selection, then calls a funtction
	#to bind the mouse movement 
	$cn->CanvasBind(
		'<Button-1>',
		[
			sub {
				my $cn       = shift;
				my $x        = shift;
				my $y        = shift;
				my $assblock = AssignBlock->find( $x, $y, \@allBlocks );
				return unless $assblock;
				$assblock->set_colour();
				my $day = $assblock->day();
				$self->_dragBind( $cn, $day, $x, $y, \@allBlocks );
			},
			Ev('x'),
			Ev('y')
		]
	);

}

sub _dragBind {
	my $self      = shift;
	my $cn        = shift;
	my $day       = shift;
	my $lx        = shift;
	my $ly        = shift;
	my $allBlocks = shift;
	my @chosen;

	#Get a list of all the AssignBlocks associated with a given day
	my @dayBlocks = AssignBlock->get_day_blocks( $day, $allBlocks );

	#Blinds motion to a motion sub to handel the selection of multiple time slots
	#when moving mouse
	$cn->CanvasBind(
		'<Motion>',
		[
			\&_motionSub, Ev('x'), Ev('y'), \$lx,
			\$ly, \@chosen, \@dayBlocks,
		]
	);

	#Binds the release of Mouse 1 to the end binding routine to open the 
	#block adding menu and unbind everything else
	$cn->CanvasBind(
		'<ButtonRelease-1>',
		[
			sub {
				my $cn     = shift;
				my $x      = shift;
				my $y1     = shift;
				my $y2     = shift;
				my $chosen = shift;
				$self->_endBinding( $cn, $x, $y1, $y2, $chosen );
			},
			$lx,
			$ly,
			Ev('y'),
			\@chosen
		]
	);
}

sub _endBinding {
	my $self   = shift;
	my $cn     = shift;
	my $x1     = shift;
	my $y1     = shift;
	my $y2     = shift;
	my $chosen = shift;
	
	#Unbind everything
	$cn->CanvasBind( '<Motion>',          sub { } );
	$cn->CanvasBind( '<Button-1>',        sub { } );
	$cn->CanvasBind( '<ButtonRelease-1>', sub { } );

	#Get the day and time of the chosen blocks
	my ( $day, $start, $duration ) =
	  AssignBlock->Get_day_start_duration($chosen);

	#create the menu to select the block to assign to the timeslot
	EditLabs->new( $cn, $self->{-schedule}, $day, $start, $duration,
		$self->obj );

	#redraw
	$self->redraw();
}

sub _motionSub {
	my $cn        = shift;
	my $x2        = shift;
	my $y2        = shift;
	my $x1        = shift;
	my $y1        = shift;
	my $chosen    = shift;
	my $dayBlocks = shift;

	#Temporarily unbind motion
	$cn->CanvasBind( '<Motion>', sub { } );

	#get the AssignBlocks currently under the slection window
	@$chosen = AssignBlock->in_range( $$x1, $$y1, $x2, $y2, $dayBlocks );

	#colour selection blue
	foreach my $blk (@$dayBlocks) {
		$blk->unfill;
	}
	foreach my $blk (@$chosen) {
		$blk->set_colour('blue');
	}

	#rebind Motion
	$cn->CanvasBind( '<Motion>',
		[ \&_motionSub, Ev('x'), Ev('y'), $x1, $y1, $chosen, $dayBlocks ] );

}

1;
