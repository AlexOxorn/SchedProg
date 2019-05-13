#!/usr/bin/perl
use strict;
use warnings;

package Streams;

use FindBin;
use lib ("$FindBin::Bin/..");
use Schedule::Stream;
use Carp;

=head1 NAME

Streams - a class containing an array of stream objects

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Streams;
    
    my $streams = Streams->new();
    
    $streams->add($stream_object);
    $streams->remove($stream_object);
    my $array = $streams->list();


=head1 DESCRIPTION

Manages the array of streams.

=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates an empty Streams object

B<Returns>

Streams object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = { -list => {} };
    bless $self, $class;
    return $self;
}

# =================================================================
# share_blocks
# =================================================================

=head2 share_blocks(block1, block2)  CLASS METHOD

Are there streams who share these two blocks?

Returns true/false

=cut

sub share_blocks {
    my $class = shift;
    my $block1 = shift;
    my $block2 = shift;
    
    
    # count occurences in both sets and ensure that all values are < 2
    my %occurences;

    # get all the streams for the first and second set.
    foreach my $stream ($block1->section->streams) {
        $occurences{$stream->id}++;
    }
    foreach my $stream ($block2->section->streams) {
        $occurences{$stream->id}++;
    }

    # a count of 2 means that they are in both sets.
    foreach my $count (values %occurences) {
        return $count if ($count >= 2);
    } 

    return;
}


# =================================================================
# add
# =================================================================

=head2 add(stream1, [stream2, ...])

Adds a new stream Streams object

Returns Streams object

=cut

sub add {
    my $self = shift;
    $self->{-list} = $self->{-list} || {};
    while (my $stream = shift) {
        confess "<"
          . ref($stream)
          . ">: invalid stream - must be a Stream object"
          unless ref($stream) && $stream->isa("Stream");
        
        $self->{-list}{$stream->id}=$stream;
    }
    return $self;
}

# =================================================================
# get
# =================================================================

=head2 get(stream_id)

Returns Streams object with id

=cut

sub get {
    my $self = shift;
    my $id = shift;
    return $self->{-list}->{$id};
}

# =================================================================
# get_by_number
# =================================================================

=head2 get_by_number(stream number)

Return stream which matches this stream number

=cut

sub get_by_number {
    my $self = shift;
    my $number = shift;
    return unless $number;
    
    foreach my $stream (@{$self->list}) {
        if ($stream->number eq $number) {
            return $stream;
        }
    }
    
    return;
    
}


# =================================================================
# get_by_id
# =================================================================

=head2 get_by_number(stream id)

Return stream which matches this stream id

=cut

sub get_by_id {
    my $self = shift;
    my $id = shift;
    return unless defined $id;
    
    foreach my $stream (@{$self->list}) {
        if ($stream->id eq $id) {
            return $stream;
        }
    }
    
    return;
    
}


# =================================================================
# remove stream 
# =================================================================

=head2 remove ($stream_object)

Removes stream from the Streams object

Returns streams object

=cut

sub remove {
    my $self = shift;
    my $stream = shift;
    
    confess "<" . ref($stream) . ">: invalid stream - must be a Stream object"
      unless ref($stream) && $stream->isa("Stream");

    delete $self->{-list}{ $stream->id }
      if exists $self->{-list}{ $stream->id };
    
    undef $stream;

    return $self;
}

# =================================================================
# list 
# =================================================================

=head2 list ()

Returns reference to array of Course objects

=cut

sub list {
    my $self = shift;
    if (wantarray) {
        return values %{ $self->{-list} };
    }
    else {
        return [values %{ $self->{-list} }];
    }
}


# =================================================================
# footer
# =================================================================

1;

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

