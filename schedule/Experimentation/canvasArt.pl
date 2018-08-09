use warnings;
use strict;
use Tk;

my $lx      = 0;
my $ly      = 0;
my $drawing = 0;

my $mw = MainWindow->new();
my $can = $mw->Canvas( -bg => 'white', -width => 800, -height => 600 )
  ->pack( -expand => 1, -fill => 'both' );

#enable_line_draw($can);
createRect($can);

MainLoop;

sub createRect {

	my $cn     = shift;
	my $xGap   = 10;
	my $yGap   = 10;
	my $width  = 100;
	my $height = 80;

	my @grid;

	foreach my $i ( 1 ... 5 ) {
		foreach my $j ( 1 ... 5 ) {

			my $r = $cn->createRectangle(
				( $i * $xGap ) + ( ( $i - 1 ) * $width ),
				( $j * $yGap ) + ( ( $j - 1 ) * $height ),
				( $i * $xGap ) + ( $i * $width ),
				( $j * $yGap ) + ( $j * $height ),
				-fill => 'grey',
				-tag  => "grid"
			);

			push @{ $grid[$j] }, $r;

			$cn->CanvasBind(
				'<Button-1>',
				sub {
					_bindEverything($cn);
				}
			);
		}
	}
}

sub _bindEverything {
	print "bind everything\n";
	my $cn = shift;
	my @list = $cn->find( 'withtag', 'grid' );

	use Data::Dumper;
	print Dumper \@list;

	#foreach my $i (@list) {
	#	print "binding <$i>\n";
	#	$cn->bind(
	#		$i,
	#		'<Motion>',
	#		sub {
	#			print "Entering button <$i> \n";
	#$cn->itemconfigure( $i, -fill => 'red' );
	#		}
	#	);
	#}
	$cn->CanvasBind(
		'<Motion>',
		[
			sub {
				my $cn = shift;
				my $x  = shift;
				my $y  = shift;
				my @i  = $cn->find( 'overlapping', $x, $y, $x, $y );
				print "@i\n";
				foreach my $i (@i) {
					$cn->itemconfigure( $i, -fill => 'red' );
				}
			},
			Ev('x'),
			Ev('y')
		]
	);

	$cn->CanvasBind(
		'<ButtonRelease-1>',
		sub {
			print "END BINDING1\n";
			_endBinding($cn);
		}
	);

}

sub _endBinding {
	print "END BINDING2\n";
	my $cn = shift;

	$cn->CanvasBind( '<Motion>', sub { } )
}

sub enable_line_draw {
	my $cn = shift;

	$cn->CanvasBind(
		'<Button-1>',
		[
			sub {
				my ( $cn, $x, $y ) = @_;
				$lx = $x;
				$ly = $y;
				_start_draw( $cn, $x, $y );
			},
			Ev('x'),
			Ev('y')
		]
	);
}

sub _start_draw {
	$drawing = 1;
	my $cn = shift;
	my $x  = shift;
	my $y  = shift;

	my $line = $cn->createLine( $lx, $ly, $x, $y );

	$cn->CanvasBind(
		'<Motion>',
		[
			sub {
				my ( $cn, $x, $y ) = @_;
				_draw_line( $cn, $line, $x, $y );

				#$lx = $x;
				#$ly = $y;
			},
			Ev('x'),
			Ev('y'),
		]
	);

	$cn->CanvasBind(
		'<ButtonRelease-1>',
		[
			sub {
				_end_drawing(@_);
			},
			Ev('x'),
			Ev('y'),
		]

	);
}

sub _draw_line {
	my $cn = shift;
	my $ln = shift;
	my $x  = shift;
	my $y  = shift;

	$cn->CanvasBind( 'Motion', sub { } );
	$cn->delete($ln);
	$ln = $cn->createLine( $lx, $ly, $x, $y );

	if ($drawing) {
		$cn->CanvasBind(
			'<Motion>',
			[
				sub {
					my ( $cn, $x, $y ) = @_;
					_draw_line( $cn, $ln, $x, $y );

					#$lx = $x;
					#$ly = $y;
				},
				Ev('x'),
				Ev('y'),
			]
		);
	}

}

sub _end_drawing {
	print "END\n";
	my $cn = shift;
	my $x  = shift;
	my $y  = shift;
	$drawing = 0;

	$cn->CanvasBind( '<Motion>', sub { } );

}
