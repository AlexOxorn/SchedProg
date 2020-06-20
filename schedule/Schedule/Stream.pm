#!/usr/bin/perl
use strict;
use warnings;

package Stream;
use Carp;
use FindBin;
use lib "$FindBin::Bin/..";
use Schedule::Time_slot;
use overload  
	fallback=> 1,
	'""' => \&print_description;

=head1 NAME

Stream - describes a cohort of students 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Stream;
    
    my $stream = Stream->new (-number=>"P322");
    $section->add_unavailable(-start=>"3:22",
                              -day=>"Mon",
                              -duration=5);
    

=head1 DESCRIPTION

Describes a group of students whose classes cannot overlap.

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;

# =================================================================
# new
# =================================================================

=head2 new ()

creates and returns a stream object

B<Parameters>

-number => Stream number

B<Returns>

Stream object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;

    confess "Bad inputs\n" if @_ % 2;
    my %inputs = @_;

    # process inputs
    my $number      = $inputs{-number}      || "A";
    my $desc        = $inputs{-descr}        || '';

    my $self = {};
    bless $self;
    
    $self->number ($number);
    $self->descr  ($desc);
	$self->{-id} = ++$Max_id;

    return $self;
}

# =================================================================
# id
# =================================================================

=head2 id ()

Returns the unique id for this stream object

=cut

sub id {
    my $self = shift;
    return $self->{-id};
}

# =================================================================
# number
# =================================================================

=head2 number ()

Sets/returns the stream number for this stream object

=cut

sub number {
    my $self = shift;
    $self->{-number} = shift if @_;
    return $self->{-number};
}

# =================================================================
# descr
# =================================================================

=head2 descr ()

Sets/returns the description for this stream object

=cut

sub descr {
    my $self = shift;
    $self->{-descr} = shift if @_;
    return $self->{-descr};
}


# =================================================================
# print_description
# =================================================================

=head2 print_description

Returns a text string that describes the stream

=cut

sub print_description {
    my $self = shift;
    my $text = $self->number;

    return $text;

}

sub print_description2 {
    my $self = shift;
    my $text = $self->number . ": " . $self->descr;

    return $text;

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


