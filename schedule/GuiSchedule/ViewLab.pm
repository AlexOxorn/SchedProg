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

	my %dayTag = (
		"1" => "monday",
		"2" => "tuesday",
		"3" => "wednesday",
		"4" => "thursday",
		"5" => "friday"
	);

	$self->SUPER::redraw();
	my @allBlocks;

	foreach my $day ( 1 ... 5 ) {
		foreach my $start ( $EarliestTime * 2 ... ( $LatestTime * 2 ) - 1 ) {
			push(@allBlocks, AssignBlock->new($self,$day,$start/2));
			#my @coords = $self->SUPER::get_time_coords( $day, $start / 2, 1 );
			#$cn->createRectangle(
			#	@coords,
			#	-outline => 'red',
			#	-width   => 3,
			#	-tags    => $dayTag{"$day"},
			#	-fill    => 'white'
			#);
		}
	}

	$cn->CanvasBind(
		'<Button-1>',
		[
			sub {
				my $cn = shift;
				my $x  = shift;
				my $y  = shift;
				my $assblock = AssignBlock->find($x,$y,\@allBlocks);
				return unless $assblock;
				$assblock->set_colour();
				my $day = $assblock->day();
				#my @i  = $cn->find( 'overlapping', $x, $y, $x, $y );
				#
				#my $i    = $i[0];
				#my @tags = $cn->gettags($i);
				#
				#my $tag = $tags[0];  # your $tag is same as my $day
				$self->_dragBind( $cn, $day, $x, $y , \@allBlocks);
			},
			Ev('x'),
			Ev('y')
		]
	);

}

sub _dragBind {
	my $self = shift;
	my $cn   = shift;
	my $day  = shift;
	my $lx   = shift;
	my $ly   = shift;
	my $allBlocks = shift;
	
	my @dayBlocks = AssignBlock->get_day_blocks($day,$allBlocks);
	#my @dayBlocks = $cn->find( 'withtag', $day );
	#

	my $temp;
	$cn->CanvasBind(
		'<Motion>',
		[
			sub {
				my $cn = shift;
				my $x2 = shift;
				my $y2 = shift;
				my $x1 = shift;
				my $y1 = shift;
				eval { $cn->delete($temp) };
				$temp = $cn->createRectangle(
					$x1, $y1, $x2, $y2,
					-width   => 6,
					-outline => "black"
				);

				my @chosen = AssignBlock->in_range($x1,$y1,$x2,$y2, \@dayBlocks);
				
				# my @chosen = $cn->find( 'overlapping', $x1, $y1, $x2, $y2 );
				#
				foreach my $blk (@dayBlocks) {
					$blk->unfill;
					#$cn->itemconfigure( $blk, -fill => 'white' );
				}
				foreach my $blk (@chosen) {
					$blk->set_colour('blue');
					#my @tags = $cn->gettags($blk);
					#if ( defined $tags[0] && $tags[0] eq $day ) {
					#	$cn->itemconfigure( $blk, -fill => 'blue' );
					#}
				}
			},
			Ev('x'),
			Ev('y'),
			$lx,
			$ly,
		]
	);

	$cn->CanvasBind(
		'<ButtonRelease-1>',
		[
			sub {
				my $x  = shift;
				my $y1 = shift;
				my $y2 = shift;
				$self->_endBinding( $cn, $x, $y1, $y2 );
			},
			$lx,
			$ly,
			Ev('y')
		]
	);
}

sub _endBinding {
	my $self = shift;
	my $cn   = shift;
	my $x1   = shift;
	my $y1   = shift;
	my $y2   = shift;

	my @time = $self->SUPER::get_block_coords( $x1, $y1, $y2 );
	use Data::Dumper;
	

}

1;
