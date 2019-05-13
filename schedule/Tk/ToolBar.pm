#!/usr/bin/perl
package Tk::Toolbar;
use strict;
use File::Basename;
use Tk::Balloon;

=head1 SYNOPSIS

    use Tk;
    use Tk::InitGui;
    use Tk::ToolBar;

    my $mw = MainWindow->new();

    # set the standard fonts and colours
    my ( $colours, $fonts ) = InitGui->set($mw);

    # create a toolbar
    my ( $buttons, $pb_props ) = gui_toolbar_menu_info();
    gui_toolbar( $buttons, $pb_props );

    MainLoop;

    # ===================================================================
    # create the toolbar
    # ===================================================================
    sub gui_toolbar {
        my $buttons = shift;
        my $b_props = shift;

        my $toolbar = $mw->ToolBar(
            -buttonbg => $colours->{WorkspaceColour},
            -hoverbg  => $colours->{ActiveBackground},
        );

        my $image_dir = "somedir";

        # create all the buttons
        foreach my $button (@$buttons) {

            # if button not defined, insert a divider
            unless ($button) {
                $toolbar->bar();
                next;
            }

            # add button
            $toolbar->add(
                -name    => $button,
                -image   => "$image_dir/$button.gif",
                -command => $b_props->{$button}{cb},
                -hint    => $b_props->{$button}{hn},
                -shortcut=> $b_props->{$button}{sc},
            );

        }

        # pack the toolbar
        $toolbar->pack( -side => 'top', -expand => 0, -fill => 'x' );
    }

    # ===================================================================
    # define button/toolbar/menu info
    # ===================================================================
    sub gui_toolbar_menu_info {

        # button names
        my @buttons = (
            'open', 'save', 'print',   '', 'skeleton',
        );
        my %b_props = (
            open => {
                cb => sub { },
                hn => 'Open file',
                sc => '<Keypress-o>',
            },
            print => {
                cb => sub { },
                hn => 'Print',
            },
            save => {
                cb => sub { },
                hn => "Save file",
            },
            skeleton => {
                cb => sub { },
                hn => 'Who is in the closet?',
            },
        );

        return \@buttons, \%b_props;

    }


=cut

# -------------------------------------------------------------------
# Create a toolbar
# -------------------------------------------------------------------
use Carp;
our $VERSION = 2.01;

use File::Find;
use Cwd;
use Tk::widgets qw/Frame/;
use base qw/Tk::Derived Tk::Frame/;

Construct Tk::Widget 'ToolBar';

sub ClassInit {
    my ( $class, $mw ) = @_;

    $class->SUPER::ClassInit($mw);

}

# ----------------------------------------------------------------------
# populate
# - options
#   -hoverbg - colour of button when mouse is hovering over it
#   -buttonbg - colour of button when mouse is not over it
# ----------------------------------------------------------------------

my $default_img;

sub Populate {
    my ( $self, $args ) = @_;

    $self->Tk::Frame::Populate($args);

    $self->ConfigSpecs(
        -hoverbg  => [ 'PASSIVE', undef, undef, undef ],
        -buttonbg => [ 'PASSIVE', undef, undef, undef ],
    );

    # some defaults
	my $pwd = cwd;
       
       use FindBin;
       my $image_dir = "$FindBin::Bin/Tk/Images";
       
       
    # search for images in default directory, depending on OS
    if ( $^O =~ /darwin/i ) {    # Mac OS linux
		find(\&wanted, $image_dir);
	}
	elsif ( $^O =~ /win/i ) {
		#find(\&wanted, $ENV{"TEMP"}."/par-.*/cache-.*/inc/");
		find(\&wanted, $ENV{"TEMP"});
	}
	else {
		find(\&wanted, $ENV{"HOME"});
	}
	# if default image not found, search directories until found (shouldn't happen)
	if(!defined $default_img) {
    	find(\&wanted, $pwd);
		while(!defined $default_img) {
			find(\&wanted, "../");
		}
	}
      
    $self->{-defaults}{-image} = $default_img;
    # buttons
    $self->{-buttons} = {};
    return $self;    # ??

}

sub wanted {
	if ($_ eq "default.gif") {
		$default_img = cwd."/".$_;
		#end search	
	}
}

# ----------------------------------------------------------------------
# add
# - adds a button
#   inputs:
#        -name => $name
#        -image => $image_file
#        -command => $callback
#        -hint => $hint
#        -shortcut => $shortcut_key
#        -disabled => [0|1]
#
# ----------------------------------------------------------------------
sub add {
    my $self    = shift;
    my %details = (@_);

    # define inputs and defaults
    my $image_file = $details{-image};
    unless ( -e $image_file ) {
        $image_file = $self->{-defaults}{-image};
    }
    my $name         = $details{-name}          || basename($image_file);
    my $callback     = $details{-command}       || sub { return };
    my $hint         = $details{-hint}          || '';
    my $shortcut_key = $details{-shortcut}      || '';
    my $disabled     = $details{-disabled}      || 0;
    my $bg           = $self->cget( -buttonbg ) || $self->cget( -bg );
    my $hbg          = $self->cget( -hoverbg )  || $self->cget( -bg );

    # define image
    my $image = $self->Photo( -file => $image_file );

    # define top level for this frame
    my $mw = $self->Parent->toplevel;

    # add button
    my $b = $self->Button(
        -text             => $name,
        -image            => $image,
        -command          => $callback,
        -relief           => 'flat',
        -bg               => $bg,
        -activebackground => $bg,
        -borderwidth      => 1,
        -highlightbackground => $bg,
        -highlightcolor   => $bg,
        -width            => 20,
        -height           => 20,
    )->pack( -side => 'left' );
    $self->{-buttons}{$name} = $b;

    # make the button slightly raised when mouse hovers
    $b->bind(
        '<Enter>',
        sub {
            $b->configure( -relief           => 'raised' );
            $b->configure( -activebackground => $hbg );
            $mw->update();
        }
    );
    $b->bind(
        '<Leave>',
        sub {
            $b->configure( -relief           => 'flat' );
            $b->configure( -activebackground => $bg );
            $mw->update();
        }
    );

    # add the tooltip
    if ($hint) {
        $mw->Balloon( -state => 'balloon' )->attach( $b, -balloonmsg => $hint );
    }

    # add the bindings for keypresses
    if ($shortcut_key) {
        $mw->bind( "<$shortcut_key>", sub { $b->invoke() } );
    }

    # disable the button?
    $b->configure( -state => 'disabled' ) if $disabled;

    return;
}

# ===========================================================================
# add a divider on the toolbar
# ===========================================================================
sub bar {
    my $self = shift;

    $self->Label(
        -text        => '',
        -bg          => $self->cget( -bg ),
        -relief      => 'raised',
        -borderwidth => 1
    )->pack( -side => 'left', -padx => 3 );
    return;
}

# ===========================================================================
# enable/disable buttons
# ===========================================================================
sub enable {
    _state( 1, @_ );
}

sub disable {
    _state( 0, @_ );
}

sub _state {
    my $action = shift;
    my $self   = shift;
    my $name   = shift;

    if ( ref( $self->{-buttons}{$name} )
        && $self->{-buttons}{$name}->isa("Tk::Button") )
    {
        $self->{-buttons}{$name}->configure( -state => 'disabled' )
          unless $action;
        $self->{-buttons}{$name}->configure( -state => 'normal' ) if $action;
    }
}

1;

