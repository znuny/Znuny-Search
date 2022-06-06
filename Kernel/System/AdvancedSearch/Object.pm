# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AdvancedSearch::Object;

use strict;
use warnings;

our @ObjectDependencies = (

);

=head1 NAME

Kernel::System::AdvancedSearch::Object - TO-DO

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE


=head2 new()

TO-DO

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 ObjectIndexAdd()

TO-DO

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexGet()

TO-DO

=cut

sub ObjectIndexGet {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexRemove()

TO-DO

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 Search()

TO-DO

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 Fallback()

TO-DO

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    return 1;
}

1;
