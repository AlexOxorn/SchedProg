#!/usr/bin/perl
use strict;
use warnings;

package GuiBlocks;
use FindBin;
use lib "$FindBin::Bin/..";
use PerlLib::Colours;
use Export::DrawView;

=head1 NAME

GuiBlock - describes the visual representation of a Block

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

	use GuiSchedule::GuiBlocks;
	use GuiSchedule::View;
	my $mw = MainWindow->new;
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $teacher  = $Schedule->teachers()->get_by_name("Sandy","Bultena");
    my $View = View->new($mw,$schedule,$teacher);

    my $block = Block->new (-day=>"Wed",-start=>"9:30",-duration=>1.5);

    my $guiblock = GuiBlocks->new( $View, $block );
    $guiBlocks->change_colour("red");
    
=head1 DESCRIPTION

Describes a GuiBlock

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;
our $Edge   = 5;

# =================================================================
# new
# =================================================================

=head2 new ()

creates, draws and returns a GuiBlocks object

B<Parameters>

-view => View the GuiBlock will be drawn on

-block => Block to turn into a GuiBlock

-coords => Where to draw the GuiBlock on the View

B<Returns>

GuiBlock object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $this   = shift;
    my $view   = shift;
    my $block  = shift;
    my $colour = shift;
    my $scale  = shift;

    # get canvas from view to draw on
    my $canvas = $view->canvas;

    # draw the block
    my $gui_objs = DrawView->draw_block($canvas,$block,$view->get_scale_info(),$view->type,$colour);

    my @lines = @{$gui_objs->{-lines}};
    my $text = $gui_objs->{-text};
    my $rectangle = $gui_objs->{-rectangle};
    my @coords = @{$gui_objs->{-coords}};
    $colour = $gui_objs->{-colour};
    
    # group rectange and text to create guiblock,
    # so that they both move as one on UI
    my $group = $canvas->createGroup( [ 0, 0 ],
                                    -members => [ $rectangle, $text, @lines ] );

    # create object
    my $self = {};
    bless $self;
    $self->{-id} = $Max_id++;
    $self->block($block);
    $self->view($view);
    $self->coords( \@coords );
    $self->colour($colour);
    $self->rectangle($rectangle);
    $self->text($text);
    $self->group($group);
    $self->is_controlled(0);

    # return object
    return $self;
}

# =================================================================
# change the colour of the guiblock
# =================================================================

=head2 change_colour ($colour)

Change the colour of the guiblock (including text and shading)

=cut

sub change_colour {
    my $self   = shift;
    my $colour = shift;
    $colour = Colour->string($colour);

    my $cn    = $self->view->canvas;
    my $group = $self->group;

    my ( $light, $dark, $textcolour ) = DrawView::get_colour_shades( $colour );

    eval {
    my ( $rect, $text, @lines ) = $cn->itemcget( $group, -members );
    $cn->itemconfigure( $rect, -fill => $colour, -outline => $colour );
    $cn->itemconfigure( $text, -fill => $textcolour );

    foreach my $i ( 0 .. @lines ) {
        $cn->itemconfigure( $lines[ $i * 2 ],     -fill => $dark->[$i] );
        $cn->itemconfigure( $lines[ $i * 2 + 1 ], -fill => $light->[$i] );
    }
    };
    if ($@) {
        print "FAILED CHANGE_COLOUR\n";
    }
}


# =================================================================
# getters/setters
# =================================================================

=head2 id ()

Returns the unique id for this guiblock object

=cut

sub id {
    my $self = shift;
    return $self->{-id};
}

=head2 block ( [block] )

Get/set the block for this guiblock

=cut

sub block {
    my $self = shift;
    $self->{-block} = shift if @_;
    return $self->{-block};
}

=head2 view ( [view] )

Get/set the view for this guiblock

=cut

sub view {
    my $self = shift;
    $self->{-view} = shift if @_;
    return $self->{-view};
}

=head2 coords ( [coords] )

Get/set the coordinates for this guiblock

=cut

sub coords {
    my $self = shift;
    $self->{-coords} = shift if @_;
    return $self->{-coords};
}

=head2 colour ( [colour] )

Get/set the colour for this guiblock

=cut

sub colour {
    my $self = shift;
    if (@_) {
        $self->{-colour} = shift;
        my $canvas    = $self->view->canvas;
        my $rectangle = $self->rectangle;
        $canvas->itemconfigure( $rectangle, -fill => $self->{-colour} );
    }
    return $self->{-colour};
}

=head2 rectangle ( [rectangle object] )

Get/set the rectangle object for this guiblock

=cut

sub rectangle {
    my $self = shift;
    $self->{-rectangle} = shift if @_;
    return $self->{-rectangle};
}

=head2 text ( [text object] )

Get/set the text object for this guiblock

=cut

sub text {
    my $self = shift;
    $self->{-text} = shift if @_;
    return $self->{-text};
}

=head2 group ( [group] )

Get/set the group for this guiblock. The group is what moves on the canvas.

=cut

sub group {
    my $self = shift;
    $self->{-group} = shift if @_;
    return $self->{-group};
}

=head2 is_controlled ( [boolean] )

Get/set the group for this guiblock. The group is what moves on the canvas.

=cut

sub is_controlled {
    my $self = shift;
    $self->{-is_controlled} = shift if @_;
    return $self->{-is_controlled};
}

# =================================================================
# footer
# =================================================================

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;
