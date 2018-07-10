#!/usr/local/bin/perl -w

use strict;
use subs qw/make_bindings move_bbox/;
use Tk;
use Tk::DragDrop;
use Tk::DropSite;

our ( $drag_id, $mw );

my $cn_type;
my $Dragged_from;
my $cn1;
my $cn2;

$mw = MainWindow->new( -background => 'green' );

my $tl1 = $mw->Toplevel( -title => 'Drag From - Rectangle' );
my $tl2 = $mw->Toplevel( -title => 'Drag To - Oval' );

$cn1 = $tl1->Canvas(qw/-background yellow/)->pack;
$cn2 = $tl2->Canvas(qw/-background cyan/)->pack;

my $drag_source =
  $cn1->DragDrop( -event => '<Shift-B1-Motion>', -sitetypes => [qw/Local/] );
my $drag_source2 =
  $cn2->DragDrop( -event => '<Shift-B1-Motion>', -sitetypes => [qw/Local/] );

my $press = sub {
	my ( $c_src, $c_src_id, $drag_source, $cnType, $origin ) = @_;
	$drag_id = $c_src_id;
	my $type = $cn1->type($drag_id);
	if ( !defined $type ) {
		$type = $cn2->type($drag_id);
	}
	$cn_type = $cnType;
	$drag_source->configure( -text => $c_src_id . " = $type" );
	$Dragged_from = $origin;
};

my $x = 30;
my $y = 30;
foreach (qw/oval rectangle/) {
	my $method = 'create' . ucfirst $_;
	my $id = $cn1->$method( $x, $y, $x + 40, $y + 40, -fill => 'orange' );
	$x += 80;
	$cn1->bind( $id, '<Shift-ButtonPress-1>' => [ $press, $id, $drag_source, "oval", "Canvas1" ] );
}

foreach (qw/oval rectangle/) {
	my $method = 'create' . ucfirst $_;
	my $id = $cn2->$method( $x, $y, $x + 40, $y + 40, -fill => 'orange' );
	$x += 80;
	$cn2->bind( $id, '<Shift-ButtonPress-1>' => [ $press, $id, $drag_source2, "rectangle", "Canvas2" ] );
}

$cn1->DropSite(
	-droptypes   => [qw/Local/],
	-dropcommand => [ \&move_items, $cn2, $cn1 ]
);

$cn2->DropSite(
	-droptypes   => [qw/Local/],
	-dropcommand => [ \&move_items, $cn1, $cn2 ]
);

my $quit = $mw->Button( -text => 'Quit', -command => [ $mw => 'destroy' ] );
$quit->pack;

MainLoop;

sub move_items {
	$_ = $_[0]->type($drag_id);
	return unless defined $_;
	
  	CASE: {
    	/oval/       and do {move_bbox  $_, @_; last CASE};
    	/rectangle/  and do {move_bbox  $_, @_; last CASE};
		warn "Unknown Canvas Type '$_'.";
	}
}

sub move_bbox {
	my ( $item_type, $c_src, $c_dest, $sel, undef, undef, $dest_x, $dest_y ) =
	  @_;
	my $fill = $c_src->itemcget( $drag_id, -fill );
	my $method = 'create' . ucfirst $item_type;
	print "item type is $item_type\ncanvas type is $cn_type\n";
	print "c_src is $c_src\nc_dest is $c_dest\n";
	print "drag_source is $drag_source\ndrag_source2 is $drag_source2\n";
	print "cn1 is $cn1\ncn2 is $cn2\n";
	if($cn_type eq $item_type && ($drag_id != $cn1 || $drag_id != $cn2)) {
		my $id = $c_dest->$method(
			$dest_x, $dest_y,
			$dest_x + 40,
			$dest_y + 40,
			-fill => $fill
		);

		make_bindings $c_dest, $id;
	} else {
		print "tried to move a $item_type into a $cn_type canvas\n";
	}
}
sub make_bindings {
	undef $drag_id;
	my ( $c_dest, $id ) = @_;

	$c_dest->bind(
		$id,
		'<ButtonPress-1>' => [
			sub {
				my ( $c, $id ) = @_;
				( $c_dest->{ 'x' . $id }, $c_dest->{ 'y' . $id } ) =
				  ( $Tk::event->x, $Tk::event->y );
			},
			$id
		]
	);

	

	$c_dest->bind(
		$id,
		'<ButtonRelease-1>' => [
			sub {
				my ( $c, $id ) = @_;
				my ( $x, $y ) = ( $Tk::event->x, $Tk::event->y );
				$c->move(
					$id,
					$x - $c_dest->{ 'x' . $id },
					$y - $c_dest->{ 'y' . $id }
				);
			},
			$id
		]
	);
}
