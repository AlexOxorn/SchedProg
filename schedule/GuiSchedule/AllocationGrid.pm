#!/usr/bin/perl
use strict;
use warnings;

package AllocationGrid;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
use PerlLib::Colours;
use Tk::Dialog;
use Tk::Menu;
use Tk::LabEntry;
use Tk::Pane;

# ============================================================================
# new
# ============================================================================

=head2 new

Creates the Grid.  Is a rather generic grid, even though it is called
AllocationGrid.  Could be repurposed for other things (maybe become a Tk widget)

B<Parameters>

* class - class type

* frame - Tk frame to draw on

* rows - how many rows do you want

* col_merge - array of sub headings 

Example, if you want this for your 2 heading rows
    
    +-------------+----------+--------------------+
    | heading1    | heading2 | heading3           |
    +------+------+----------+------+------+------+
    | sub1 | sub2 | sub1     | sub1 | sub2 | sub3 |
    +------+------+----------+------+------+------+

use col_merge = [2,1,3]

* data_entry_callback - a callback function called everytime
there data widget is modified.  row/col are sent as parameters
to the callback

B<Returns>

AllocationGrid object

=cut    

sub new {
    my $class               = shift;
    my $frame               = shift;
    my $rows                = shift;
    my $col_merge           = shift;
    my @col_merge           = @$col_merge;
    my $data_entry_callback = shift || sub { return 1;no strict; no warnings; print join(", ",@_),"\n" if @_;return 1 };

    my $self = bless {}, $class;

    # ------------------------------------------------------------------------
    # some instance data we need to keep
    # ------------------------------------------------------------------------
    my %data_entry_widgets;
    my %data_widgets_rowcol;
    my @sub_header_widgets;
    my @header_widgets;
    my @row_widgets;

    $self->header_widgets( \@header_widgets );
    $self->sub_header_widgets( \@sub_header_widgets );
    $self->row_header_widgets( \@row_widgets );
    $self->entry_widgets( \%data_entry_widgets );

    # width of the data entry (fixed for now... maybe make it configurable
    # at a later date)
    my $width = 4;

    # ------------------------------------------------------------------------
    # get rid of anything that is currently on this frame
    # ------------------------------------------------------------------------
    foreach my $w ($frame->packSlaves) {
        $w->destroy;
    }

    # ------------------------------------------------------------------------
    # make a 2x3 grid with frames for
    # blank | header | blank
    # teacher | data | totals
    # ------------------------------------------------------------------------
    my $header_frame = $frame->Frame( -bg => "blue" );
    my $row_frame    = $frame->Frame( -bg => 'pink' );
    my $data_frame   = $frame->Frame( -bg => 'yellow' );
    my $totals_frame = $frame->Frame( -bg => 'green' );

    $header_frame->grid( -row => 0, -column => 1, -sticky => 'w' );
    $row_frame->grid( -row => 1, -column => 0, -sticky => 'nw' );
    $data_frame->grid( -row => 1, - column => 1, -sticky => 'nw' );
    $totals_frame->grid( -row => 1, -column => 2, -sticky => 'nw' );

    $frame->gridColumnconfigure( 3, -weight => 2 );

    # ------------------------------------------------------------------------
    # make the header columns
    # ------------------------------------------------------------------------

    my $header_colour1  = "#abcdef";
    my $header_colour2  = Colour->lighten( 5, $header_colour1 );
    my $very_light_grey = "#eeeeee";

    # merged header
    foreach my $col ( 0 .. @col_merge - 1 ) {

        # frame to hold the merged header, and the sub-headings
        my $mini_frame =
          $header_frame->Frame( -bg => 'black' )->pack( -side => 'left' );

        # widget
        my $me = $mini_frame->Entry(
            -width   => $width,
            -relief  => 'flat',
            -bg      => $header_colour1,
            -justify => 'center',
        )->pack( -side => 'top', -expand => 0, -fill => 'both' );

        # reset colours to normal after we disable the widget
        my $bg = $me->cget('-bg');
        my $fg = $me->cget('-fg');
        $me->configure( -state              => 'disabled' );
        $me->configure( -disabledbackground => $bg );
        $me->configure( -disabledforeground => $fg );

        # change colour every second merged header
        if ( $col % 2 ) {
            $me->configure( -disabledbackground => $header_colour2 );
        }

        # keep these widgets so that they can be configured later
        push @header_widgets, $me;

        # --------------------------------------------------------------------
        # subsections
        # --------------------------------------------------------------------
        foreach my $sub_section ( 1 .. $col_merge[$col] ) {

            # frame within the mini-frame so we can stack 'left'
            my $hf2 =
              $mini_frame->Frame( -bg => 'blue' )->pack( -side => 'left' );

            # widget
            my $se = $hf2->Entry(
                -relief    => 'flat',
                -width     => $width,
                -justify   => 'center',
                -bg        => $header_colour1,
                -takefocus => 0,
            )->pack( -side => 'left' );

            # reset colours to normal after we disable the widget
            my $bg = $se->cget('-bg');
            my $fg = $se->cget('-fg');
            $se->configure( -state              => 'disabled' );
            $se->configure( -disabledbackground => $bg );
            $se->configure( -disabledforeground => $fg );

            # change colour every second merged header
            if ( $col % 2 ) {
                $se->configure( -disabledbackground => $header_colour2 );
            }

            # keep these widgets so that they can be configured later
            push @sub_header_widgets, $se;
        }
    }

    # ------------------------------------------------------------------------
    # row titles
    # ------------------------------------------------------------------------

    foreach my $row ( 1 .. $rows ) {
        my $re = $row_frame->Entry(
            -takefocus => 0,
            -relief    => 'flat',
            -width     => 12,
        )->pack( -side => 'top' );

        # reset colours to normal after we disable the widget
        my $bg = $re->cget('-bg');
        my $fg = $re->cget('-fg');
        $re->configure( -state              => 'disabled' );
        $re->configure( -disabledbackground => $bg );
        $re->configure( -disabledforeground => $fg );

        push @row_widgets, $re;
    }

    # ------------------------------------------------------------------------
    # data grid
    # ------------------------------------------------------------------------
    my %data;
    my $row = 0;
    my $col = 0;
    foreach my $row ( 1 .. $rows ) {
        my $df1 = $data_frame->Frame()->pack( -side => 'top' );

        # foreach col
        foreach my $col ( 0 .. @col_merge - 1 ) {

            # subsections
            foreach my $sub_section ( 1 .. $col_merge[$col] ) {

                # data entry box
                my $de = $df1->Entry(
                    -relief          => 'flat',
                    -width           => $width,
                    -justify         => 'center',
                    -validate        => 'key',
                    -validatecommand => [ $data_entry_callback, $row, $col ],
                    -invalidcommand => sub { $df1->bell },
                )->pack( -side => 'left' );

                # save row/column with dataentry, and vice-versa
                $data_entry_widgets{$row}{$col} = $de;
                $data_widgets_rowcol{$de} = [ $row, $col ];

                # set colour in column to make it easier to read
                unless ( $col % 2 ) {
                    $de->configure( -bg => $very_light_grey );
                }

                # set bindings for navigation
                # key bindings for this entry widget
                $de->bind( "<Tab>",            [ \&_nextCell, $self ] );
                $de->bind( "<Key-Return>",     [ \&_nextCell, $self ] );
                $de->bind( "<Shift-Tab>",      [ \&_prevCell, $self ] );
                $de->bind( "<Key-Left>",       [ \&_prevCell, $self ] );
                $de->bind( "<Key-leftarrow>",  [ \&_prevCell, $self ] );
                $de->bind( "<Key-Up>",         [ \&_prevRow,  $self ] );
                $de->bind( "<Key-uparrow>",    [ \&_prevRow,  $self ] );
                $de->bind( "<Key-Down>",       [ \&_nextRow,  $self ] );
                $de->bind( "<Key-downarrow>",  [ \&_nextRow,  $self ] );
                $de->bind( "<Key-Right>",      [ \&_nextCell, $self ] );
                $de->bind( "<Key-rightarrow>", [ \&_nextCell, $self ] );

                #$de->bind( "<Button>",         [ \&_select_all, $self ] );

                # I want my bindings to happen BEFORE the class bindings
                $de->bindtags( [ ( $de->bindtags )[ 1, 0, 2, 3 ] ] );

            }
        }
    }
    return $self;

}

sub populate {
    my $self            = shift;
    my $header_text     = shift;
    my $sub_header_text = shift;
    my $row_header_text = shift;
    my $data_vars       = shift;

    foreach my $col ( 1 .. $self->num_cols ) {
        foreach my $row ( 1 .. $self->num_rows ) {
            my $widget = $self->get_widget( $row, $col );
            $widget->configure( -textvariable => $data_vars->[$row][$col] )
              if $widget;
        }
    }

    my $i              = 0;
    my $header_widgets = $self->header_widgets;
    while ( my $var = shift @$header_text ) {
        $header_widgets->[$i]->configure( -textvariable => \$var );
        $i++;
    }
    $i = 0;
    my $sub_header_widgets = $self->sub_header_widgets;
    while ( my $var = shift @$sub_header_text ) {
        if ( exists $sub_header_widgets->[$i] ) {
            $sub_header_widgets->[$i]->configure( -textvariable => \$var );
            $i++;
        }
    }
    $i = 0;
    my $row_header_widgets = $self->row_header_widgets;
    while ( my $var = shift @$row_header_text ) {
        $row_header_widgets->[$i]->configure( -textvariable => \$var );
        $i++;
    }

}

sub _nextRow {
    my $self = shift;
}

sub _prevRow {
    my $self = shift;
}

sub _nextCell {
    my $self = shift;
}

sub _prevCell {
    my $self = shift;
}

sub _row_col {
    my $self = shift;
    return;

    # if moving to row/col, do so
    if (@_) {
        my $row     = shift;
        my $col     = shift;
        my $widgets = $self->data_entry_widgets;
        if ( exists $widgets->{$row}->{$col} ) {
            $widgets->{$row}->{$col}->setFocus();
            return ( $row, $col );
        }
    }
}

# ============================================================================
# Getters and setters
# ============================================================================
sub entry_widgets {
    my $self = shift;
    $self->{-widgets} = shift if @_;
    $self->{-widgets} = {} unless $self->{-widgets};
    return $self->{-widgets};
}

sub get_widget {
    my $self    = shift;
    my $row     = shift;
    my $col     = shift;
    my $widgets = $self->entry_widgets;
    return $widgets->{$row}{$col};
}

sub get_row_col {
    my $self     = shift;
    my $widget   = shift;
    my $row_cols = $self->entry_row_cols;
    return $row_cols->{$widget};
}

sub entry_row_cols {
    my $self = shift;
    $self->{-row_col} = shift if @_;
    $self->{-row_col} = {} unless $self->{-row_col};
    return $self->{-row_col};
}

sub header_widgets {
    my $self = shift;
    $self->{-header_widgets} = shift if @_;
    $self->{-header_widgets} = [] unless $self->{-header_widgets};
    return $self->{-header_widgets};
}

sub sub_header_widgets {
    my $self = shift;
    $self->{-sub_header_widgets} = shift if @_;
    $self->{-sub_header_widgets} = [] unless $self->{-sub_header_widgets};
    return $self->{-sub_header_widgets};
}

sub row_header_widgets {
    my $self = shift;
    $self->{-row_header_widgets} = shift if @_;
    $self->{-row_header_widgets} = [] unless $self->{-row_header_widgets};
    return $self->{-row_header_widgets};
}

sub num_rows {
    my $self = shift;
    my $rows = $self->row_header_widgets;
    return scalar( @{$rows} );
}

sub num_cols {
    my $self = shift;
    my $cols = $self->sub_header_widgets;
    return scalar( @{$cols} );
}

1;

__END__
        #        my $text = $course->number;
        #        $text =~ s/420-//;

        #my @sections = sort { $a->number cmp $b->number } $course->sections;


   #        my @sections = sort { $a->number cmp $b->number } $course->sections;

       # foreach section
       #          foreach my $section (@sections) {
       #              $data{ $teacher->id }{ $section->id }{ $course->id } = '';

       # get hours for each section for each teacher
       #              if ( $section->has_teacher($teacher) ) {
       #                  $data{ $teacher->id }{ $section->id }{ $course->id } =
       #                    $section->hours;
       #              }
