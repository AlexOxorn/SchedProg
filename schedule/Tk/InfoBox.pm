#!/usr/bin/perl

package Tk::InfoBox;

use strict;
use Carp;

our $VERSION = "19.00.000";

use Tk::widgets qw/LabEntry Label Button/;
use base qw(Tk::Toplevel);

Tk::Widget->Construct('InfoBox');

sub ClassInit {
   my ($class, $mw) = @_;
   
   $class->SUPER::ClassInit($mw);
}

sub Populate {
    my ($self, $args) = @_;

    $self->SUPER::Populate($args);
    $self->transient($self->Parent->toplevel);
    $self->withdraw();

    # frames for icon and message / button
    my $top = $self->Frame()->pack(-expand=>1,-fill=>'both');
    my $bot = $self->Frame()->pack(-fill=>'y');
    
    # icon
    my $w_bitmap = $top->Label(Name => 'bitmap');
    $w_bitmap->pack(-side => 'left', -padx => '3m', -pady => '3m');

    # text
    my $label = $top->Label()->pack(-side=>'left');
    $label->configure(-justify=>'left',-padx=>10,-pady=>3,-relief=>'flat');

    # ok button
    $self->{selected_button} = 0;
    my $ok = $bot->Button(-text=>'Ok',-command=>sub{$self->{selected_button}=1;}
                         )->pack(-side=>'bottom');
   
    # prevent the dialog box from being deleted
    $self->protocol('WM_DELETE_WINDOW' => sub {});
    
    # advertised widgets
    $self->Advertise('label'   => $label);
    $self->Advertise('bitmap'  => $w_bitmap );
    $self->Advertise('ok'      => $ok);

    # configurable options
    $self->ConfigSpecs(
		       -message	    => ['PASSIVE', undef, undef, undef],
                       -bitmap     => ['bitmap',undef,undef,undef],
                       -timeout    => ['PASSIVE',undef,undef,0],
                      );
}

sub Show {
    my $self = shift;
    my $label = $self->Subwidget('label');
    my $text = $self->cget(-message);
    $label->configure(-text=>$text);

    # show the message box wherever the cursor is
    $self->Popup(-popover=>'cursor',-overanchor=>'c');
    $self->grab();
    
    # annoy the user by repeatedly popping this message box
    # to the foreground
    $self->repeat(5000,sub{$self->raise()});

    # wait until the user has hit the button, or timeout
    # has been invoked
    my $timeout = $self->cget(-timeout);
    if ($timeout) {
        $self->after($timeout,sub{$self->{selected_button}=2});
    }
    $self->waitVariable(\$self->{selected_button});
    
    # release the focus
    $self->grabRelease();
    $self->destroy();
    return 1;
}
