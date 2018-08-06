#!/usr/bin/perl
use strict;
use warnings;

package Teacher;
use Carp;
use overload  
	fallback=> 1,
	'""' => \&print_description;
use Scalar::Util 'refaddr';


=head1 NAME

Teacher - create the Teacher object

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Teacher;
    
    my $teacher = Teacher->new (-firstname => $name, 
                                -lastname => $lname,
                                -dept     => $dept
                               );
    

=head1 DESCRIPTION

Describes a teacher

=head1 METHODS

=cut

# =================================================================
# Class variables
# =================================================================
our $Max_id;

# =================================================================
# new
# =================================================================

=head2 new (...)

creates and returns a teacher object

B<Parameters>

-firstname => first name of teacher

-lastname => last name of teacher

-dept => department that teacher is associated with (optional)

B<Returns>

Teacher object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    confess "Bad inputs" if @_%2;

    my %inputs = @_; 
    my $fname = $inputs{-firstname} || "";
    my $lname = $inputs{-lastname} || "";
    my $dept = $inputs{-dept} || "";
    
    my $self = { };
    bless $self, $class;
    
    $self->firstname($fname);
    $self->lastname($lname);
    $self->dept($dept);
    $self->{-id} = ++$Max_id;
    
    return $self;
}


# =================================================================
# id
# =================================================================

=head2 id ()

Returns the unique id for this teacher object

=cut

sub id {
    my $self = shift;
    return $self->{-id}
}

# =================================================================
# firstname
# =================================================================

=head2 firstname ( [name] )

Gets and sets the teacher's name

=cut

sub firstname {
    my $self = shift;
    $self->{-fname} = shift if @_;
    return $self->{-fname}
}

# =================================================================
# lastname
# =================================================================

=head2 lastname ( [name] )

Gets and sets the teacher's last name

=cut

sub lastname {
    my $self = shift;
    if (@_) {
        my $lname = shift;
        confess ("Last name cannot be an empty string") if $lname eq "";
        $self->{-lname} = $lname;
    }
    return $self->{-lname}
}

# =================================================================
# dept
# =================================================================

=head2 dept ( [dept] )

Gets and sets the teacher's department name

=cut

sub dept {
    my $self = shift;
    $self->{-dept} = shift if @_;
    return $self->{-dept}
}

# =================================================================
# release
# =================================================================

=head2 release ( [release] )

How much release time does the teacher have (per week)
from teaching duties?

=cut

sub release {
    my $self = shift;
    $self->{-release} = shift if @_;
    return $self->{-release}
}

# =================================================================
# print_description
# =================================================================

=head2 print_description

Returns a text string that describes the teacher

=cut

sub print_description {
    my $self = shift;
    my $text = "";

    $text .=
        $self->firstname . " "
      . $self->lastname;

    return $text;

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

